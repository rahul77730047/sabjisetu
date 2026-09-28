// node-postgres returns NUMERIC/DECIMAL columns as strings (to avoid
// silent float rounding). The frontend does plain JS arithmetic on
// these fields, so we convert the numeric ones back to numbers here,
// right at the edge, once, instead of scattering Number(...) calls
// throughout the React app.
export function toNum(row, fields) {
  const out = { ...row };
  fields.forEach((f) => {
    if (out[f] !== null && out[f] !== undefined) out[f] = Number(out[f]);
  });
  return out;
}

export function todayIST() {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Kolkata", year: "numeric", month: "2-digit", day: "2-digit"
  }).formatToParts(new Date());
  const p = Object.fromEntries(parts.map(x => [x.type, x.value]));
  return `${p.year}-${p.month}-${p.day}`;
}

// Canonical Customer Due Synchronization Helper used across all routes
export async function syncCustomerDue(db, cid) {
  const custRes = await db.query("SELECT id, name FROM customers WHERE id = $1", [cid]);
  if (!custRes.rows.length) return null;
  const cname = custRes.rows[0].name;

  const summary = await db.query(`
    SELECT
      COALESCE((SELECT SUM(amount) FROM sales WHERE lower(trim(customer)) = lower(trim($1)) AND status = 'Due'), 0) AS due_sales,
      COALESCE((SELECT SUM(amount) FROM sales WHERE lower(trim(customer)) = lower(trim($1))), 0) AS total_business,
      COALESCE((SELECT SUM(amount) FROM customer_payments WHERE customer_id = $2 OR customer_id IN (SELECT id FROM customers WHERE lower(trim(name)) = lower(trim($1)))), 0) AS total_payments,
      (SELECT TO_CHAR(MAX(date), 'YYYY-MM-DD') FROM sales WHERE lower(trim(customer)) = lower(trim($1)) AND status = 'Due') AS due_date
  `, [cname, cid]);

  const dueSales = Number(summary.rows[0].due_sales || 0);
  const totalBusiness = Number(summary.rows[0].total_business || 0);
  const totalPayments = Number(summary.rows[0].total_payments || 0);
  const remainingDue = Math.max(0, Number((dueSales - totalPayments).toFixed(2)));
  const dueDate = summary.rows[0].due_date;
  const today = todayIST();

  const status = remainingDue <= 0 ? "Upcoming" : (dueDate < today ? "Overdue" : (dueDate === today ? "Due Today" : "Upcoming"));

  await db.query(
    "UPDATE customers SET due = $1, business = $2, due_date = $3, status = $4 WHERE lower(trim(name)) = lower(trim($5)) OR id = $6",
    [remainingDue, totalBusiness, dueDate || null, status, cname, cid]
  );

  return {
    id: cid,
    name: cname,
    due: remainingDue,
    business: totalBusiness,
    due_date: dueDate,
    status
  };
}

export async function ensureItemMaster(db, item, specification = null) {
  const name = String(item || '').trim();
  if (!name) return null;

  const result = await db.query(
    `INSERT INTO item_master(name_en, name_hi, active)
     VALUES($1, '', true)
     ON CONFLICT ((lower(trim(name_en))))
     DO UPDATE SET name_en = item_master.name_en
     RETURNING id`,
    [name]
  );

  const itemId = result.rows[0]?.id;
  if (!itemId) return null;

  const spec = String(specification || '').trim();
  if (spec) {
    await db.query(
      `INSERT INTO item_specifications(item_id, name, active)
       VALUES($1, $2, true)
       ON CONFLICT DO NOTHING`,
      [itemId, spec]
    );
    await db.query(
      `UPDATE item_specifications
       SET active=true
       WHERE item_id=$1 AND lower(trim(name))=lower(trim($2))`,
      [itemId, spec]
    );
  }

  return itemId;
}

export async function recordStockMovement(db, { item, specification, qty_change, unit_cost, source_type, source_id, movement_date }) {
  await db.query(
    `INSERT INTO stock_movements (item, specification, qty_change, unit_cost, source_type, source_id, movement_date)
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [item, specification, qty_change, unit_cost, source_type, source_id, movement_date || todayIST()]
  );
}
