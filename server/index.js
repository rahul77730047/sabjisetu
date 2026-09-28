import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { pool } from "./db.js";

import { mandiPurchasesRouter } from "./routes/mandiPurchases.js";
import { localPurchasesRouter } from "./routes/localPurchases.js";
import { stockRouter } from "./routes/stock.js";
import { salesRouter } from "./routes/sales.js";
import { customersRouter } from "./routes/customers.js";
import { expensesRouter } from "./routes/expenses.js";
import { labourRouter } from "./routes/labour.js";
import { whatsappBillsRouter } from "./routes/whatsappBills.js";
import { notificationsRouter } from "./routes/notifications.js";
import { settingsRouter } from "./routes/settings.js";
import { reportsRouter } from "./routes/reports.js";
import { paymentsRouter } from "./routes/payments.js";
import { mastersRouter } from "./routes/masters.js";
import { backupRouter } from "./routes/backup.js";
import { authRouter, verifyToken, hashPassword } from "./routes/auth.js";
import bcrypt from "bcryptjs";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

app.get("/api/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ ok: true, db: "connected" });
  } catch (err) {
    res.status(500).json({ ok: false, db: "unreachable", error: err.message });
  }
});

let dbInitPromise = null;

app.use(async (_req, _res, next) => {
  if (dbInitPromise) {
    try {
      await dbInitPromise;
    } catch (err) {
      console.error("[server] Database initialization error:", err.message);
    }
  }
  next();
});

app.use("/api/auth", authRouter);

// Protected routes
app.use("/api/mandi-purchases", verifyToken, mandiPurchasesRouter);
app.use("/api/local-purchases", verifyToken, localPurchasesRouter);
app.use("/api/stock", verifyToken, stockRouter);
app.use("/api/stock-movements", verifyToken, (req, res, next) => {
  req.url = "/movements" + (req.url === "/" ? "" : req.url);
  stockRouter(req, res, next);
});
app.use("/api/sales", verifyToken, salesRouter);
app.use("/api/customers", verifyToken, customersRouter);
app.use("/api/expenses", verifyToken, expensesRouter);
app.use("/api/labour", verifyToken, labourRouter);
app.use("/api/whatsapp-bills", verifyToken, whatsappBillsRouter);
app.use("/api/notifications", verifyToken, notificationsRouter);
app.use("/api/settings", verifyToken, settingsRouter);
app.use("/api/reports", verifyToken, reportsRouter);
app.use("/api/payments", verifyToken, paymentsRouter);
app.use("/api/masters", verifyToken, mastersRouter);
app.use("/api/backup", verifyToken, backupRouter);

const PORT = process.env.PORT || 4000;

app.listen(PORT, () => {
  console.log(`[server] SabziSetu API running on http://localhost:${PORT}`);
  console.log(`[server] Health check: http://localhost:${PORT}/api/health`);
});

async function runMigrations() {
  try {
    await pool.query(`ALTER TABLE business_settings ADD COLUMN IF NOT EXISTS low_stock_threshold_kg NUMERIC(14,3) NOT NULL DEFAULT 50`);
    await pool.query(`ALTER TABLE customers ADD COLUMN IF NOT EXISTS phone TEXT`);
    await pool.query(`ALTER TABLE business_settings ADD COLUMN IF NOT EXISTS whatsapp_send_all_enabled BOOLEAN NOT NULL DEFAULT true`);
    await pool.query(`CREATE EXTENSION IF NOT EXISTS pgcrypto`);

    // Auth Initialization
    await pool.query(`CREATE TABLE IF NOT EXISTS admin_users (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), username TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL, display_name TEXT, role TEXT NOT NULL DEFAULT 'Admin', active BOOLEAN NOT NULL DEFAULT true, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now())`);
    await pool.query(`CREATE TABLE IF NOT EXISTS admin_sessions (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), admin_user_id UUID NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE, token_hash TEXT NOT NULL UNIQUE, expires_at TIMESTAMPTZ NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now())`);

    // Legacy migration to new admin_users
    const userCheck = await pool.query("SELECT * FROM admin_users WHERE username = 'admin'");
    if (userCheck.rows.length === 0) {
      const hashedPassword = hashPassword("admin123");
      await pool.query("INSERT INTO admin_users (username, password_hash, display_name) VALUES ('admin', $1, 'System Administrator')", [hashedPassword]);
      console.log("[server] Default admin created (admin / admin123)");
    }

    await pool.query(`CREATE TABLE IF NOT EXISTS stock (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), item TEXT NOT NULL, specification TEXT, qty NUMERIC(14,3) NOT NULL DEFAULT 0, avg_cost NUMERIC(14,2) NOT NULL DEFAULT 0, selling_price NUMERIC(14,2) NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'Available', updated_at TIMESTAMPTZ NOT NULL DEFAULT now())`);
    await pool.query(`CREATE TABLE IF NOT EXISTS stock_movements (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), item TEXT NOT NULL, specification TEXT, qty_change NUMERIC(14,3) NOT NULL, unit_cost NUMERIC(14,2), source_type TEXT NOT NULL, source_id UUID, movement_date DATE NOT NULL DEFAULT CURRENT_DATE, created_at TIMESTAMPTZ NOT NULL DEFAULT now())`);

    for (const q of [
      `ALTER TABLE sales ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'Cash'`,
      `ALTER TABLE sales ADD COLUMN IF NOT EXISTS transaction_id TEXT`,
      `ALTER TABLE sales ADD COLUMN IF NOT EXISTS payment_proof TEXT`,
      `ALTER TABLE customer_payments ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'Cash'`,
      `ALTER TABLE customer_payments ADD COLUMN IF NOT EXISTS transaction_id TEXT`,
      `ALTER TABLE customer_payments ADD COLUMN IF NOT EXISTS payment_proof TEXT`,
      `ALTER TABLE customer_payments ADD COLUMN IF NOT EXISTS source_sale_id UUID`,
      `ALTER TABLE whatsapp_bills ADD COLUMN IF NOT EXISTS kind TEXT DEFAULT 'Bill'`,
      `ALTER TABLE whatsapp_bills ADD COLUMN IF NOT EXISTS message TEXT`,
      `ALTER TABLE whatsapp_bills ADD COLUMN IF NOT EXISTS payment_method TEXT`,
      `ALTER TABLE whatsapp_bills ADD COLUMN IF NOT EXISTS payment_proof TEXT`,
      `ALTER TABLE notifications ADD COLUMN IF NOT EXISTS notification_key TEXT`,
      `ALTER TABLE notifications ADD COLUMN IF NOT EXISTS action_message TEXT`,
      `ALTER TABLE notifications ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT true`,
    ]) await pool.query(q);

    await pool.query(`CREATE TABLE IF NOT EXISTS unit_master (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT NOT NULL, symbol TEXT NOT NULL, kg_multiplier NUMERIC(14,6) NOT NULL CHECK (kg_multiplier > 0), active BOOLEAN NOT NULL DEFAULT true, created_at TIMESTAMPTZ NOT NULL DEFAULT now())`);
    await pool.query(`CREATE UNIQUE INDEX IF NOT EXISTS unit_master_name_unique_idx ON unit_master (lower(trim(name)))`);
    await pool.query(`CREATE TABLE IF NOT EXISTS vendor_master (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT NOT NULL, vendor_type TEXT NOT NULL DEFAULT 'Both' CHECK (vendor_type IN ('Mandi','Local','Both')), active BOOLEAN NOT NULL DEFAULT true, created_at TIMESTAMPTZ NOT NULL DEFAULT now())`);
    await pool.query(`CREATE UNIQUE INDEX IF NOT EXISTS vendor_master_name_unique_idx ON vendor_master (lower(trim(name)))`);
    await pool.query(`CREATE TABLE IF NOT EXISTS expense_category_master (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT NOT NULL, active BOOLEAN NOT NULL DEFAULT true, created_at TIMESTAMPTZ NOT NULL DEFAULT now())`);
    await pool.query(`CREATE UNIQUE INDEX IF NOT EXISTS expense_category_master_name_unique_idx ON expense_category_master (lower(trim(name)))`);
    for (const q of [
      `ALTER TABLE stock ADD COLUMN IF NOT EXISTS specification TEXT`,
      `ALTER TABLE mandi_purchases ADD COLUMN IF NOT EXISTS specification TEXT`, `ALTER TABLE mandi_purchases ADD COLUMN IF NOT EXISTS quantity_value NUMERIC(14,3)`, `ALTER TABLE mandi_purchases ADD COLUMN IF NOT EXISTS quantity_unit TEXT DEFAULT 'Kg'`,
      `ALTER TABLE local_purchases ADD COLUMN IF NOT EXISTS specification TEXT`, `ALTER TABLE local_purchases ADD COLUMN IF NOT EXISTS quantity_value NUMERIC(14,3)`, `ALTER TABLE local_purchases ADD COLUMN IF NOT EXISTS quantity_unit TEXT DEFAULT 'Kg'`,
      `ALTER TABLE sales ADD COLUMN IF NOT EXISTS specification TEXT`, `ALTER TABLE sales ADD COLUMN IF NOT EXISTS quantity_value NUMERIC(14,3)`, `ALTER TABLE sales ADD COLUMN IF NOT EXISTS quantity_unit TEXT DEFAULT 'Kg'`,
    ]) await pool.query(q);
    await pool.query(`DROP INDEX IF EXISTS stock_item_unique_idx`);
    await pool.query(`CREATE UNIQUE INDEX IF NOT EXISTS stock_item_spec_unique_idx ON stock (lower(trim(item)), lower(trim(coalesce(specification,''))))`);
    await pool.query(`INSERT INTO unit_master(name,symbol,kg_multiplier) VALUES ('Kilogram','Kg',1),('Quintal','Quintal',100),('Bag','Bag',50),('Carat','Carat',25) ON CONFLICT DO NOTHING`);
    await pool.query(`INSERT INTO expense_category_master(name) VALUES ('Transport'),('Loading / Unloading'),('Market Charges'),('Electricity'),('Other') ON CONFLICT DO NOTHING`);
    await pool.query(`INSERT INTO item_master(name_en) SELECT DISTINCT trim(item) FROM (SELECT item FROM stock UNION SELECT item FROM mandi_purchases UNION SELECT item FROM local_purchases UNION SELECT item FROM sales) x WHERE trim(item)<>'' ON CONFLICT ((lower(trim(name_en)))) DO NOTHING`);
    await pool.query(`INSERT INTO item_specifications(item_id,name) SELECT im.id, trim(x.specification) FROM item_master im JOIN (SELECT DISTINCT item,specification FROM stock UNION SELECT DISTINCT item,specification FROM mandi_purchases UNION SELECT DISTINCT item,specification FROM local_purchases UNION SELECT DISTINCT item,specification FROM sales) x ON lower(trim(x.item))=lower(trim(im.name_en)) WHERE trim(coalesce(x.specification,''))<>'' ON CONFLICT DO NOTHING`);
  } catch (err) {
    console.error('[server] Database migration failed:', err.message);
    process.exit(1);
  }
}

dbInitPromise = runMigrations();
