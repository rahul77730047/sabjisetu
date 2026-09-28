-- SabziSetu production schema
-- Run once against PostgreSQL. This schema intentionally contains no demo/seed transactions.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS business_settings (
  id INT PRIMARY KEY DEFAULT 1,
  name TEXT NOT NULL DEFAULT 'SabziSetu',
  owner TEXT NOT NULL DEFAULT 'Owner',
  tagline TEXT NOT NULL DEFAULT 'Smart Trading, Higher Earning',
  currency TEXT NOT NULL DEFAULT '₹',
  whatsapp_send_all_enabled BOOLEAN NOT NULL DEFAULT true,
  low_stock_threshold_kg NUMERIC(14,3) NOT NULL DEFAULT 50,
  CONSTRAINT single_row CHECK (id = 1)
);

-- Admin & Sessions
CREATE TABLE IF NOT EXISTS admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  display_name TEXT,
  role TEXT NOT NULL DEFAULT 'Admin',
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS admin_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Stock & Movements
CREATE TABLE IF NOT EXISTS stock (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item TEXT NOT NULL,
  specification TEXT,
  qty NUMERIC(14,3) NOT NULL DEFAULT 0 CHECK (qty >= 0),
  avg_cost NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (avg_cost >= 0),
  selling_price NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (selling_price >= 0),
  status TEXT NOT NULL DEFAULT 'Available',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS stock_item_spec_unique_idx ON stock (lower(trim(item)), lower(trim(coalesce(specification,''))));

CREATE TABLE IF NOT EXISTS stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item TEXT NOT NULL,
  specification TEXT,
  qty_change NUMERIC(14,3) NOT NULL,
  unit_cost NUMERIC(14,2),
  source_type TEXT NOT NULL, -- purchase, sale, manual, opening
  source_id UUID,
  movement_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Purchases
CREATE TABLE IF NOT EXISTS mandi_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  vendor TEXT NOT NULL,
  item TEXT NOT NULL,
  specification TEXT,
  qty NUMERIC(14,3) NOT NULL CHECK (qty > 0),
  quantity_value NUMERIC(14,3),
  quantity_unit TEXT DEFAULT 'Kg',
  rate NUMERIC(14,2) NOT NULL CHECK (rate >= 0),
  amount NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS local_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  vendor TEXT NOT NULL,
  item TEXT NOT NULL,
  specification TEXT,
  qty NUMERIC(14,3) NOT NULL CHECK (qty > 0),
  quantity_value NUMERIC(14,3),
  quantity_unit TEXT DEFAULT 'Kg',
  rate NUMERIC(14,2) NOT NULL CHECK (rate >= 0),
  amount NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Customers & Payments
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT,
  due NUMERIC(14,2) NOT NULL DEFAULT 0,
  business NUMERIC(14,2) NOT NULL DEFAULT 0,
  due_date DATE,
  status TEXT NOT NULL DEFAULT 'Upcoming',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS customers_name_unique_idx ON customers (lower(trim(name)));

CREATE TABLE IF NOT EXISTS sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  customer TEXT NOT NULL,
  item TEXT NOT NULL,
  specification TEXT,
  qty NUMERIC(14,3) NOT NULL CHECK (qty > 0),
  quantity_value NUMERIC(14,3),
  quantity_unit TEXT DEFAULT 'Kg',
  rate NUMERIC(14,2) NOT NULL CHECK (rate >= 0),
  amount NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
  status TEXT NOT NULL DEFAULT 'Due' CHECK (status IN ('Due','Paid')),
  cogs NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (cogs >= 0),
  payment_method TEXT DEFAULT 'Cash',
  transaction_id TEXT,
  payment_proof TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS customer_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  amount NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  payment_method TEXT DEFAULT 'Cash', -- Cash, UPI, Bank
  transaction_id TEXT,
  payment_proof TEXT,
  source_sale_id UUID,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Other
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  category TEXT NOT NULL,
  note TEXT,
  amount NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS labour (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  name TEXT NOT NULL,
  work_type TEXT NOT NULL,
  workers INT NOT NULL DEFAULT 1 CHECK (workers > 0),
  amount NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS whatsapp_bills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer TEXT NOT NULL,
  phone TEXT,
  amount NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  status TEXT NOT NULL DEFAULT 'Not sent',
  kind TEXT DEFAULT 'Bill', -- Bill, Reminder, Payment
  message TEXT,
  source_payment_id UUID,
  source_sale_id UUID,
  payment_method TEXT,
  payment_proof TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  text TEXT NOT NULL,
  time TEXT,
  read BOOLEAN NOT NULL DEFAULT false,
  action_type TEXT,
  action_value TEXT,
  notification_key TEXT,
  action_message TEXT,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO business_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- Safe upgrades for databases created with the previous demo schema.
ALTER TABLE sales ADD COLUMN IF NOT EXISTS cogs NUMERIC(14,2) NOT NULL DEFAULT 0;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS action_type TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS action_value TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS stock_item_unique_idx ON stock (lower(trim(item)));
CREATE UNIQUE INDEX IF NOT EXISTS customers_name_unique_idx ON customers (lower(trim(name)));

-- Safe upgrade for customer contact numbers.
ALTER TABLE customers ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE stock ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'Available';
ALTER TABLE business_settings ADD COLUMN IF NOT EXISTS whatsapp_send_all_enabled BOOLEAN NOT NULL DEFAULT true;


-- Master data used by the UI. Masters keep item names, specifications, units,
-- vendors and expense categories consistent instead of relying on hardcoded values.
CREATE TABLE IF NOT EXISTS item_master (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_en TEXT NOT NULL,
  name_hi TEXT NOT NULL DEFAULT '',
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS item_master_name_unique_idx ON item_master (lower(trim(name_en)));

CREATE TABLE IF NOT EXISTS item_specifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id UUID NOT NULL REFERENCES item_master(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS item_spec_unique_idx ON item_specifications (item_id, lower(trim(name)));

CREATE TABLE IF NOT EXISTS unit_master (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  symbol TEXT NOT NULL,
  kg_multiplier NUMERIC(14,6) NOT NULL CHECK (kg_multiplier > 0),
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS unit_master_name_unique_idx ON unit_master (lower(trim(name)));

CREATE TABLE IF NOT EXISTS vendor_master (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  vendor_type TEXT NOT NULL DEFAULT 'Both' CHECK (vendor_type IN ('Mandi','Local','Both')),
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS vendor_master_name_unique_idx ON vendor_master (lower(trim(name)));

CREATE TABLE IF NOT EXISTS expense_category_master (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS expense_category_master_name_unique_idx ON expense_category_master (lower(trim(name)));

-- Optional specification + original quantity unit/value. qty remains the
-- normalized kilogram quantity used for all stock calculations.
ALTER TABLE stock ADD COLUMN IF NOT EXISTS specification TEXT;
ALTER TABLE mandi_purchases ADD COLUMN IF NOT EXISTS specification TEXT;
ALTER TABLE mandi_purchases ADD COLUMN IF NOT EXISTS quantity_value NUMERIC(14,3);
ALTER TABLE mandi_purchases ADD COLUMN IF NOT EXISTS quantity_unit TEXT DEFAULT 'Kg';
ALTER TABLE local_purchases ADD COLUMN IF NOT EXISTS specification TEXT;
ALTER TABLE local_purchases ADD COLUMN IF NOT EXISTS quantity_value NUMERIC(14,3);
ALTER TABLE local_purchases ADD COLUMN IF NOT EXISTS quantity_unit TEXT DEFAULT 'Kg';
ALTER TABLE sales ADD COLUMN IF NOT EXISTS specification TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS quantity_value NUMERIC(14,3);
ALTER TABLE sales ADD COLUMN IF NOT EXISTS quantity_unit TEXT DEFAULT 'Kg';

DROP INDEX IF EXISTS stock_item_unique_idx;
CREATE UNIQUE INDEX IF NOT EXISTS stock_item_spec_unique_idx
  ON stock (lower(trim(item)), lower(trim(coalesce(specification,''))));

-- Safe defaults. Existing databases get these only if they do not already exist.
INSERT INTO unit_master(name,symbol,kg_multiplier) VALUES
  ('Kilogram','Kg',1),
  ('Quintal','Quintal',100),
  ('Bag','Bag',50),
  ('Carat','Carat',25)
ON CONFLICT DO NOTHING;

INSERT INTO expense_category_master(name) VALUES
  ('Transport'),('Loading / Unloading'),('Market Charges'),('Electricity'),('Other')
ON CONFLICT DO NOTHING;
