import { Router } from "express";
import { pool } from "../db.js";

export const notificationsRouter = Router();

notificationsRouter.get("/", async (_req, res) => {
  try {
    const { rows } = await pool.query(`
      WITH due AS (
        SELECT c.id, c.name, c.phone,
          GREATEST(0, COALESCE(SUM(CASE WHEN s.status='Due' THEN s.amount ELSE 0 END), 0) - COALESCE((SELECT SUM(amount) FROM customer_payments cp WHERE cp.customer_id=c.id), 0)) due,
          MAX(CASE WHEN s.status='Due' THEN s.date END) due_date
        FROM customers c LEFT JOIN sales s ON lower(trim(s.customer))=lower(trim(c.name)) GROUP BY c.id
      ), dynamic AS (
        SELECT gen_random_uuid() id,
               CASE WHEN due_date < CURRENT_DATE THEN name||' has an overdue payment of ₹'||to_char(due,'FM999,999,990')||'.' ELSE name||' has a payment of ₹'||to_char(due,'FM999,999,990')||' due today.' END text,
               CASE WHEN due_date < CURRENT_DATE THEN 'Overdue' ELSE 'Due today' END time,
               'whatsapp' action_type, phone action_value,
               'due:'||c_id||':'||coalesce(due_date::text, '')||':'||due::text notification_key,
               'Send reminder' action_message,
               true active,
               now() created_at
        FROM (SELECT id c_id, name, phone, due, due_date FROM due WHERE due > 0 AND due_date <= CURRENT_DATE) x
        UNION ALL
        SELECT gen_random_uuid(),
               'Stock of '||item||' is low ('||to_char(qty,'FM999,999,990.###')||' Kg left).',
               'Stock alert',
               'stock', item,
               'stock:'||id||':'||qty::text notification_key,
               'Restock soon' action_message,
               true active,
               now() created_at
        FROM stock, business_settings WHERE qty <= business_settings.low_stock_threshold_kg
      )
      SELECT
        d.id, d.text, d.time,
        COALESCE(n.read, false) AS read,
        d.action_type, d.action_value, d.notification_key, d.action_message, d.active, d.created_at
      FROM dynamic d
      LEFT JOIN notifications n ON lower(trim(n.notification_key)) = lower(trim(d.notification_key))
      WHERE d.active = true
      UNION ALL
      SELECT id, text, time, read, action_type, action_value, notification_key, action_message, active, created_at
      FROM notifications
      WHERE active = true AND (notification_key IS NULL OR lower(trim(notification_key)) NOT IN (SELECT lower(trim(notification_key)) FROM dynamic))
      ORDER BY created_at DESC LIMIT 100
    `);
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Failed to load notifications" });
  }
});

notificationsRouter.patch("/mark-all-read", async (_req, res) => {
  try {
    const getRes = await pool.query(`
      WITH due AS (
        SELECT c.id, c.name, c.phone,
          GREATEST(0, COALESCE(SUM(CASE WHEN s.status='Due' THEN s.amount ELSE 0 END), 0) - COALESCE((SELECT SUM(amount) FROM customer_payments cp WHERE cp.customer_id=c.id), 0)) due,
          MAX(CASE WHEN s.status='Due' THEN s.date END) due_date
        FROM customers c LEFT JOIN sales s ON lower(trim(s.customer))=lower(trim(c.name)) GROUP BY c.id
      )
      SELECT 'due:'||id||':'||coalesce(due_date::text, '')||':'||due::text AS notification_key,
             CASE WHEN due_date < CURRENT_DATE THEN name||' has an overdue payment of ₹'||to_char(due,'FM999,999,990')||'.' ELSE name||' has a payment of ₹'||to_char(due,'FM999,999,990')||' due today.' END AS text,
             CASE WHEN due_date < CURRENT_DATE THEN 'Overdue' ELSE 'Due today' END AS time,
             'whatsapp' AS action_type, phone AS action_value, 'Send reminder' AS action_message
      FROM due WHERE due > 0 AND due_date <= CURRENT_DATE
      UNION ALL
      SELECT 'stock:'||id||':'||qty::text AS notification_key,
             'Stock of '||item||' is low ('||to_char(qty,'FM999,999,990.###')||' Kg left).' AS text,
             'Stock alert' AS time,
             'stock' AS action_type, item AS action_value, 'Restock soon' AS action_message
      FROM stock, business_settings WHERE qty <= business_settings.low_stock_threshold_kg
    `);

    for (const row of getRes.rows) {
      if (row.notification_key) {
        await pool.query(`
          INSERT INTO notifications (text, time, read, action_type, action_value, notification_key, action_message, active)
          VALUES ($1, $2, true, $3, $4, $5, $6, true)
          ON CONFLICT (notification_key) DO UPDATE SET read = true
        `, [row.text, row.time, row.action_type, row.action_value, row.notification_key, row.action_message]);
      }
    }

    await pool.query("UPDATE notifications SET read = true");
    res.json({ success: true, updated: getRes.rows.length });
  } catch (e) {
    console.error("[notifications/mark-all-read]", e);
    res.status(500).json({ error: "Failed to mark notifications as read" });
  }
});

notificationsRouter.patch("/:id", async (req, res) => {
  try {
    const { rows } = await pool.query("UPDATE notifications SET read=$1 WHERE id=$2 RETURNING *", [Boolean(req.body.read), req.params.id]);
    if (!rows.length) return res.status(404).json({ error: "Notification is generated dynamically and cannot be changed" });
    res.json(rows[0]);
  } catch (e) {
    res.status(400).json({ error: "Failed to update notification" });
  }
});
