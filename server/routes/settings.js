import { Router } from "express";
import { pool } from "../db.js";

export const settingsRouter = Router();

settingsRouter.get("/", async (_req, res) => {
  try {
    const { rows } = await pool.query("SELECT * FROM business_settings WHERE id = 1");
    const row = rows[0] || { name: "SabziSetu", owner: "Owner", tagline: "", currency: "₹", whatsapp_send_all_enabled: true, low_stock_threshold_kg: 50, theme_color: "#173F35" };
    res.json({
      ...row,
      themeColor: row.theme_color || row.themeColor || "#173F35",
      theme_color: row.theme_color || row.themeColor || "#173F35",
      lowStockThresholdKg: row.low_stock_threshold_kg,
      whatsappSendAllEnabled: row.whatsapp_send_all_enabled,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to load settings" });
  }
});

settingsRouter.put("/whatsapp-send-all", async (req, res) => {
  const enabled = req.body?.whatsapp_send_all_enabled === true || req.body?.whatsappSendAllEnabled === true;
  try {
    const { rows } = await pool.query(
      `INSERT INTO business_settings (id, name, owner, tagline, currency, whatsapp_send_all_enabled)
       VALUES (1, 'SabziSetu', 'Owner', '', '₹', $1)
       ON CONFLICT (id) DO UPDATE SET whatsapp_send_all_enabled = $1
       RETURNING *`,
      [enabled]
    );
    const row = rows[0];
    res.json({
      ...row,
      themeColor: row.theme_color || row.themeColor || "#173F35",
      theme_color: row.theme_color || row.themeColor || "#173F35",
      lowStockThresholdKg: row.low_stock_threshold_kg,
      whatsappSendAllEnabled: row.whatsapp_send_all_enabled,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update WhatsApp Send to All setting" });
  }
});

settingsRouter.put("/", async (req, res) => {
  const {
    name,
    owner,
    tagline,
    currency,
    whatsapp_send_all_enabled,
    whatsappSendAllEnabled,
    low_stock_threshold_kg,
    lowStockThresholdKg,
    theme_color,
    themeColor,
  } = req.body;

  const colorVal = String(theme_color || themeColor || "").trim();
  const waSendAllVal = whatsapp_send_all_enabled !== undefined ? whatsapp_send_all_enabled : whatsappSendAllEnabled;
  const thresholdVal = low_stock_threshold_kg !== undefined ? low_stock_threshold_kg : lowStockThresholdKg;

  try {
    const check = await pool.query("SELECT id FROM business_settings WHERE id = 1");

    if (check.rows.length > 0) {
      const fields = [];
      const vals = [];
      if (name !== undefined) { fields.push(`name = $${vals.length + 1}`); vals.push(name); }
      if (owner !== undefined) { fields.push(`owner = $${vals.length + 1}`); vals.push(owner); }
      if (tagline !== undefined) { fields.push(`tagline = $${vals.length + 1}`); vals.push(tagline); }
      if (currency !== undefined) { fields.push(`currency = $${vals.length + 1}`); vals.push(currency); }
      if (waSendAllVal !== undefined) { fields.push(`whatsapp_send_all_enabled = $${vals.length + 1}`); vals.push(waSendAllVal); }
      if (thresholdVal !== undefined) { fields.push(`low_stock_threshold_kg = $${vals.length + 1}`); vals.push(thresholdVal); }
      if (colorVal) { fields.push(`theme_color = $${vals.length + 1}`); vals.push(colorVal); }

      if (fields.length === 0) {
        const current = await pool.query("SELECT * FROM business_settings WHERE id = 1");
        const r = current.rows[0];
        return res.json({
          ...r,
          themeColor: r.theme_color || r.themeColor || "#173F35",
          theme_color: r.theme_color || r.themeColor || "#173F35",
          lowStockThresholdKg: r.low_stock_threshold_kg,
          whatsappSendAllEnabled: r.whatsapp_send_all_enabled,
        });
      }

      vals.push(1);
      const { rows } = await pool.query(
        `UPDATE business_settings SET ${fields.join(", ")} WHERE id = $${vals.length} RETURNING *`,
        vals
      );
      const row = rows[0];
      res.json({
        ...row,
        themeColor: row.theme_color || row.themeColor || "#173F35",
        theme_color: row.theme_color || row.themeColor || "#173F35",
        lowStockThresholdKg: row.low_stock_threshold_kg,
        whatsappSendAllEnabled: row.whatsapp_send_all_enabled,
      });
    } else {
      const { rows } = await pool.query(
        `INSERT INTO business_settings (id, name, owner, tagline, currency, whatsapp_send_all_enabled, low_stock_threshold_kg, theme_color)
         VALUES (1, $1, $2, $3, $4, $5, $6, $7) RETURNING *`,
        [
          name || 'SabziSetu',
          owner || 'Owner',
          tagline || '',
          currency || '₹',
          waSendAllVal === undefined ? true : waSendAllVal,
          thresholdVal === undefined ? 50 : thresholdVal,
          colorVal || '#173F35'
        ]
      );
      const row = rows[0];
      res.json({
        ...row,
        themeColor: row.theme_color || row.themeColor || "#173F35",
        theme_color: row.theme_color || row.themeColor || "#173F35",
        lowStockThresholdKg: row.low_stock_threshold_kg,
        whatsappSendAllEnabled: row.whatsapp_send_all_enabled,
      });
    }
  } catch (err) {
    console.error("[settings/put]", err);
    res.status(500).json({ error: "Failed to save settings" });
  }
});
