import { Router } from "express";
import { pool } from "../db.js";

export const backupRouter = Router();

backupRouter.get("/export", async (_req, res) => {
  try {
    const tables = [
      "business_settings", "item_master", "item_specifications", "unit_master",
      "vendor_master", "expense_category_master", "customers", "stock",
      "mandi_purchases", "local_purchases", "sales", "customer_payments",
      "expenses", "labour", "whatsapp_bills", "notifications"
    ];

    const backup = {};
    for (const table of tables) {
      const { rows } = await pool.query(`SELECT * FROM ${table}`);
      backup[table] = rows;
    }

    res.setHeader("Content-Disposition", "attachment; filename=sabzisetu_backup.json");
    res.json(backup);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to export backup" });
  }
});

// Note: Import logic would require carefully handling UUIDs and foreign keys.
// For now, we provide export as requested in "Backup / Export".
