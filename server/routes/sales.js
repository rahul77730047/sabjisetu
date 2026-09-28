import { Router } from "express";
import { pool } from "../db.js";
import { toNum, todayIST, ensureItemMaster } from "./helpers.js";

export const salesRouter = Router();
const mapOut = (row) => {
  const r = toNum(row, ["qty", "rate", "amount", "cogs", "quantity_value"]);
  return {
    ...r,
    specification: r.specification || "",
    quantity_unit: r.quantity_unit || "Kg",
    quantity_value: r.quantity_value ?? r.qty
  };
};

salesRouter.get("/", async (_req, res) => {
  try {
    const { rows } = await pool.query("SELECT * FROM sales ORDER BY date DESC, created_at DESC");
    res.json(rows.map(mapOut));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to load sales" });
  }
});

salesRouter.post("/", async (req, res) => {
  const date = req.body.date || null;
  const customer = String(req.body.customer || "").trim();
  const item = String(req.body.item || "").trim();
  const specification = String(req.body.specification || "").trim() || null;
  const quantity_value = Number(req.body.quantityValue ?? req.body.quantity_value ?? req.body.qty);
  const quantity_unit = String(req.body.quantityUnit ?? req.body.quantity_unit ?? "Kg").trim();
  const rate = Number(req.body.rate);
  const status = req.body.status === "Paid" ? "Paid" : "Due";
  const phone = String(req.body.phone || "").trim();
  const payment_method = String(req.body.payment_method || "Cash").trim();
  const transaction_id = String(req.body.transaction_id || "").trim();

  if (!date) return res.status(400).json({ error: "Date is required" });
  if (!customer) return res.status(400).json({ error: "Customer is required" });
  if (!item) return res.status(400).json({ error: "Item is required" });
  if (!Number.isFinite(quantity_value) || quantity_value <= 0) return res.status(400).json({ error: "Quantity must be greater than 0" });
  if (!Number.isFinite(rate) || rate < 0) return res.status(400).json({ error: "Rate cannot be negative" });

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const unit = await client.query("SELECT kg_multiplier FROM unit_master WHERE lower(trim(name))=lower(trim($1)) OR lower(trim(symbol))=lower(trim($1)) LIMIT 1", [quantity_unit]);
    if (!unit.rows.length) throw new Error(`Unknown quantity unit: ${quantity_unit}. Add it in Master Settings.`);
    const qty = Number((quantity_value * Number(unit.rows[0].kg_multiplier)).toFixed(3));
    const amount = Number((qty * rate).toFixed(2));

    const stock = await client.query(
      "SELECT * FROM stock WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,''))) FOR UPDATE",
      [item, specification]
    );
    if (!stock.rows.length) throw new Error(`No stock exists for ${item}. Add a purchase/opening stock first.`);

    const s = stock.rows[0];
    const available = Number(s.qty);
    if (available < qty) throw new Error(`Insufficient ${item} stock. Available: ${available} Kg.`);

    const cogs = Number((qty * Number(s.avg_cost)).toFixed(2));
    const inserted = await client.query(
      `INSERT INTO sales (date,customer,item,specification,qty,quantity_value,quantity_unit,rate,amount,status,cogs,payment_method,transaction_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING *`,
      [date, customer, item, specification, qty, quantity_value, quantity_unit, rate, amount, status, cogs, payment_method, transaction_id]
    );

    // Record stock movement (negative change for sale)
    await client.query(
      `INSERT INTO stock_movements (item, specification, qty_change, unit_cost, source_type, source_id, movement_date)
       VALUES ($1, $2, $3, $4, 'sale', $5, $6)`,
      [item, specification, -qty, s.avg_cost, inserted.rows[0].id, date]
    );

    await client.query(
      "UPDATE stock SET qty=qty-$1,updated_at=now() WHERE id=$2",
      [qty, s.id]
    );

    const cust = await client.query(
      "SELECT * FROM customers WHERE lower(trim(name))=lower(trim($1)) FOR UPDATE",
      [customer]
    );

    if (cust.rows.length) {
      await client.query(
        `UPDATE customers
         SET phone=CASE WHEN $5<>'' THEN $5 ELSE phone END,
             business=business+$1,
             due_date=CASE WHEN $2='Due' THEN $3 ELSE due_date END,
             status=CASE WHEN $2='Due' THEN CASE WHEN $3<CURRENT_DATE THEN 'Overdue' WHEN $3=CURRENT_DATE THEN 'Due Today' ELSE 'Upcoming' END ELSE status END
         WHERE id=$4`,
        [amount, status, date, cust.rows[0].id, phone]
      );
    } else {
      await client.query(
        `INSERT INTO customers(name,phone,due,business,due_date,status)
         VALUES($1,$6,$2,$3,$4,$5)`,
        [customer, status === "Due" ? amount : 0, amount, status === "Due" ? date : null,
          status === "Due" ? (date < todayIST() ? "Overdue" : date === todayIST() ? "Due Today" : "Upcoming") : "Upcoming", phone]
      );
    }

    await client.query("COMMIT");
    res.status(201).json(mapOut(inserted.rows[0]));
  } catch (err) {
    await client.query("ROLLBACK");
    console.error(err);
    res.status(400).json({ error: err.message });
  } finally {
    client.release();
  }
});

// Edit fields of a sale.
// Note: Updating quantity or item name will impact stock and requires recalculation.
salesRouter.patch("/:id", async (req, res) => {
  const { id } = req.params;
  const { date, customer, phone, item, specification, quantity_value, quantity_unit, rate, status } = req.body;
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const found = await client.query("SELECT * FROM sales WHERE id=$1 FOR UPDATE", [id]);
    if (!found.rows.length) throw new Error("Sale not found.");
    const old = found.rows[0];

    // If stock-impacting fields changed, we reverse old then apply new
    const isStockImpact = (item && item !== old.item) ||
                          (specification !== undefined && specification !== old.specification) ||
                          (quantity_value !== undefined && Number(quantity_value) !== Number(old.quantity_value)) ||
                          (quantity_unit !== undefined && quantity_unit !== old.quantity_unit);

    if (isStockImpact) {
      // 1. Reverse old stock
      await client.query("UPDATE stock SET qty = qty + $1 WHERE lower(trim(item)) = lower(trim($2)) AND lower(trim(coalesce(specification,''))) = lower(trim(coalesce($3,'')))", [old.qty, old.item, old.specification]);

      // 2. Prepare new values
      const newItem = item || old.item;
      const newSpec = specification !== undefined ? specification : old.specification;
      const newQtyVal = quantity_value !== undefined ? Number(quantity_value) : Number(old.quantity_value);
      const newQtyUnit = quantity_unit || old.quantity_unit;
      const newRate = rate !== undefined ? Number(rate) : Number(old.rate);

      const unitRes = await client.query("SELECT kg_multiplier FROM unit_master WHERE lower(trim(name))=lower(trim($1)) OR lower(trim(symbol))=lower(trim($1)) LIMIT 1", [newQtyUnit]);
      if (!unitRes.rows.length) throw new Error(`Unknown unit: ${newQtyUnit}`);

      const multiplier = Number(unitRes.rows[0].kg_multiplier);
      const newQtyKg = Number((newQtyVal * multiplier).toFixed(3));
      const newAmount = Number((newQtyKg * newRate).toFixed(2));

      // 3. Check and apply new stock
      const stockCheck = await client.query("SELECT * FROM stock WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,''))) FOR UPDATE", [newItem, newSpec]);
      if (!stockCheck.rows.length) throw new Error(`Stock record for ${newItem} not found.`);
      if (Number(stockCheck.rows[0].qty) < newQtyKg) throw new Error(`Insufficient stock for ${newItem}. Available: ${stockCheck.rows[0].qty} Kg.`);

      await client.query("UPDATE stock SET qty = qty - $1 WHERE id = $2", [newQtyKg, stockCheck.rows[0].id]);

      // 4. Update sale record with new calculations
      const cogs = Number((newQtyKg * Number(stockCheck.rows[0].avg_cost)).toFixed(2));
      await client.query(
        `UPDATE sales SET date=COALESCE($1,date), customer=COALESCE($2,customer), item=$3, specification=$4, qty=$5, quantity_value=$6, quantity_unit=$7, rate=$8, amount=$9, status=COALESCE($10,status), cogs=$11 WHERE id=$12`,
        [date, customer, newItem, newSpec, newQtyKg, newQtyVal, newQtyUnit, newRate, newAmount, status, cogs, id]
      );
    } else {
      // Simple non-stock update (customer, phone, rate, status, etc.)
      const newRate = rate !== undefined ? Number(rate) : Number(old.rate);
      const newAmount = Number((Number(old.qty) * newRate).toFixed(2));

      await client.query(
        `UPDATE sales SET date=COALESCE($1,date), customer=COALESCE($2,customer), rate=$3, amount=$4, status=COALESCE($5,status) WHERE id=$6`,
        [date, customer, newRate, newAmount, status, id]
      );
    }

    // Sync Customer (Phone, Business, Due)
    const finalCustomer = customer || old.customer;
    const finalPhone = phone || "";
    const custResult = await client.query("SELECT id FROM customers WHERE lower(trim(name)) = lower(trim($1)) FOR UPDATE", [finalCustomer]);
    if (custResult.rows.length) {
      const cid = custResult.rows[0].id;
      if (finalPhone) await client.query("UPDATE customers SET phone = $1 WHERE id = $2", [finalPhone, cid]);

      // Recalculate customer summary
      const summary = await client.query(`
        SELECT
          COALESCE((SELECT SUM(amount) FROM sales WHERE lower(trim(customer))=lower(trim($1))), 0) AS business,
          GREATEST(0, COALESCE((SELECT SUM(amount) FROM sales WHERE lower(trim(customer))=lower(trim($1)) AND status='Due'), 0)
          - COALESCE((SELECT SUM(amount) FROM customer_payments WHERE customer_id=$2), 0)) AS due,
          (SELECT TO_CHAR(MAX(date), 'YYYY-MM-DD') FROM sales WHERE lower(trim(customer))=lower(trim($1)) AND status='Due') AS due_date
      `, [finalCustomer, cid]);

      const { business, due, due_date: dueDate } = summary.rows[0];
      const today = todayIST();
      const customerStatus = Number(due) <= 0 ? "Upcoming" : (dueDate < today ? "Overdue" : (dueDate === today ? "Due Today" : "Upcoming"));
      await client.query("UPDATE customers SET business=$1, due=$2, due_date=$3, status=$4 WHERE id=$5", [business, due, dueDate, customerStatus, cid]);
    }

    const updated = await client.query("SELECT * FROM sales WHERE id=$1", [id]);
    await client.query("COMMIT");
    res.json(mapOut(updated.rows[0]));

  } catch (err) {
    await client.query("ROLLBACK");
    console.error("[sales/patch]", err);
    res.status(400).json({ error: err.message || "Failed to update sale." });
  } finally {
    client.release();
  }
});

salesRouter.delete("/:id", async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const found = await client.query("SELECT * FROM sales WHERE id=$1 FOR UPDATE", [req.params.id]);
    if (!found.rows.length) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Not found" });
    }

    const sale = found.rows[0];
    const stock = await client.query(
      "SELECT * FROM stock WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,''))) FOR UPDATE",
      [sale.item, sale.specification]
    );
    if (!stock.rows.length) throw new Error("Stock record for this sale no longer exists.");

    await client.query(
      "UPDATE stock SET qty=qty+$1,updated_at=now() WHERE id=$2",
      [sale.qty, stock.rows[0].id]
    );

    const cust = await client.query(
      "SELECT id FROM customers WHERE lower(trim(name))=lower(trim($1)) FOR UPDATE",
      [sale.customer]
    );

    await client.query("DELETE FROM sales WHERE id=$1", [req.params.id]);

    if (cust.rows.length) {
      const dueResult = await client.query(
        `SELECT GREATEST(
           0,
           COALESCE((SELECT SUM(amount) FROM sales WHERE lower(trim(customer))=lower(trim($1)) AND status='Due'),0)
           - COALESCE((SELECT SUM(amount) FROM customer_payments WHERE customer_id=$2),0)
         ) due`,
        [sale.customer, cust.rows[0].id]
      );
      const due = Number(dueResult.rows[0].due || 0);
      const latest = await client.query(
        `SELECT TO_CHAR(MAX(date), 'YYYY-MM-DD') AS due_date FROM sales WHERE lower(trim(customer))=lower(trim($1)) AND status='Due'`,
        [sale.customer]
      );
      const dueDate = latest.rows[0].due_date;
      const today = todayIST();
      const status = due <= 0 ? "Upcoming" : dueDate < today ? "Overdue" : dueDate === today ? "Due Today" : "Upcoming";
      await client.query("UPDATE customers SET business=GREATEST(0,business-$1),due=$2,due_date=$3,status=$4 WHERE id=$5", [sale.amount,due,dueDate||null,status,cust.rows[0].id]);
    }

    await client.query("COMMIT");
    res.status(204).end();
  } catch (err) {
    await client.query("ROLLBACK");
    console.error(err);
    res.status(400).json({ error: err.message });
  } finally {
    client.release();
  }
});
