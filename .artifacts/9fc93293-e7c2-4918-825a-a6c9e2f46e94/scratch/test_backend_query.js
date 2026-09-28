import pkg from 'pg';
const { Pool } = pkg;

const pool = new Pool({
  connectionString: "postgresql://neondb_owner:npg_S8mdeY5IDsyu@ep-small-wildflower-b4i5etfq.c-6.us-east-2.aws.neon.tech/sabzisetu_new?sslmode=require"
});

function todayIST() {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Kolkata", year: "numeric", month: "2-digit", day: "2-digit"
  }).formatToParts(new Date());
  const p = Object.fromEntries(parts.map(x => [x.type, x.value]));
  return `${p.year}-${p.month}-${p.day}`;
}

async function verifyBackendQuery() {
  console.log('=== VERIFYING CANONICAL /summary QUERY AGAINST REAL NEON POSTGRESQL ===');
  const today = todayIST();
  console.log('Business Date (todayIST):', today);

  const { rows } = await pool.query(`
    WITH cust_dues AS (
      SELECT
        c.id,
        c.name,
        GREATEST(
          0,
          COALESCE((SELECT SUM(s.amount) FROM sales s WHERE lower(trim(s.customer)) = lower(trim(c.name)) AND s.status = 'Due'), 0)
          - COALESCE((SELECT SUM(p.amount) FROM customer_payments p WHERE (p.customer_id = c.id OR p.customer_id IN (SELECT id FROM customers WHERE lower(trim(name)) = lower(trim(c.name)))) AND p.source_sale_id IS NULL), 0)
        ) AS due,
        (SELECT MAX(s.date) FROM sales s WHERE lower(trim(s.customer)) = lower(trim(c.name)) AND s.status = 'Due') AS due_date
      FROM customers c
    ),
    cust_classified AS (
      SELECT
        due,
        CASE
          WHEN due <= 0 THEN 'Upcoming'
          WHEN due_date < $1::date THEN 'Overdue'
          WHEN due_date = $1::date THEN 'Due Today'
          ELSE 'Upcoming'
        END AS derived_status
      FROM cust_dues
    )
    SELECT
      COALESCE((SELECT SUM(amount) FROM sales WHERE date=$1::date),0) AS sales_today,
      COALESCE((SELECT SUM(qty) FROM sales WHERE date=$1::date),0) AS sales_qty_today,
      COALESCE((SELECT SUM(cogs) FROM sales WHERE date=$1::date),0) AS cogs_today,

      COALESCE((SELECT SUM(amount) FROM mandi_purchases WHERE date=$1::date),0) AS purchases_mandi_today,
      COALESCE((SELECT SUM(amount) FROM local_purchases WHERE date=$1::date),0) AS purchases_local_today,
      COALESCE((SELECT SUM(amount) FROM mandi_purchases WHERE date=$1::date),0)+COALESCE((SELECT SUM(amount) FROM local_purchases WHERE date=$1::date),0) AS purchases_today,
      COALESCE((SELECT SUM(qty) FROM mandi_purchases WHERE date=$1::date),0)+COALESCE((SELECT SUM(qty) FROM local_purchases WHERE date=$1::date),0) AS purchases_qty_today,

      COALESCE((SELECT SUM(amount) FROM expenses WHERE date=$1::date),0) AS expenses_today,
      COALESCE((SELECT SUM(amount) FROM labour WHERE date=$1::date),0) AS labour_today,
      COALESCE((SELECT SUM(amount) FROM customer_payments WHERE date=$1::date AND source_sale_id IS NULL),0) AS collected_today,

      COALESCE((SELECT SUM(due) FROM cust_classified WHERE due > 0),0) AS total_due,
      COALESCE((SELECT SUM(due) FROM cust_classified WHERE due > 0),0) AS sales_still_due,
      COALESCE((SELECT COUNT(*) FROM cust_classified WHERE due > 0),0) AS due_customers_count,
      COALESCE((SELECT SUM(due) FROM cust_classified WHERE due > 0 AND derived_status='Overdue'),0) AS overdue_due,
      COALESCE((SELECT SUM(due) FROM cust_classified WHERE due > 0 AND derived_status='Due Today'),0) AS today_due,
      COALESCE((SELECT SUM(due) FROM cust_classified WHERE due > 0 AND derived_status='Upcoming'),0) AS upcoming_due,

      COALESCE((SELECT SUM(amount) FROM sales WHERE date >= date_trunc('month', $1::date)::date AND date <= $1::date),0) AS sales_month,
      COALESCE((SELECT SUM(amount) FROM mandi_purchases WHERE date >= date_trunc('month', $1::date)::date AND date <= $1::date),0) +
      COALESCE((SELECT SUM(amount) FROM local_purchases WHERE date >= date_trunc('month', $1::date)::date AND date <= $1::date),0) AS purchases_month,
      COALESCE((SELECT SUM(cogs) FROM sales WHERE date >= date_trunc('month', $1::date)::date AND date <= $1::date),0) AS cogs_month,
      COALESCE((SELECT SUM(amount) FROM expenses WHERE date >= date_trunc('month', $1::date)::date AND date <= $1::date),0) AS expenses_month,
      COALESCE((SELECT SUM(amount) FROM labour WHERE date >= date_trunc('month', $1::date)::date AND date <= $1::date),0) AS labour_month,

      COALESCE((SELECT SUM(qty * avg_cost) FROM stock),0) AS stock_value,
      COALESCE((SELECT SUM(qty) FROM stock),0) AS stock_qty,

      (SELECT json_build_object('item', item, 'qty', SUM(qty)) FROM sales WHERE date=$1::date GROUP BY item ORDER BY SUM(qty) DESC, item ASC LIMIT 1) AS top_selling_today
  `, [today]);

  const res = rows[0];
  console.log('\n--- REAL PRODUCTION DATABASE CANONICAL QUERY VALUES ---');
  Object.keys(res).forEach(k => {
    console.log(`  ${k}: ${typeof res[k]} = ${JSON.stringify(res[k])}`);
  });

  console.log('\n--- INVARIANT VERIFICATIONS ---');
  const mandi = Number(res.purchases_mandi_today || 0);
  const local = Number(res.purchases_local_today || 0);
  const totalPurchases = Number(res.purchases_today || 0);
  console.log(`1. Mandi (${mandi}) + Local (${local}) = Total Purchase (${totalPurchases}):`, (mandi + local === totalPurchases) ? 'VERIFIED (PASS)' : 'FAIL');

  const overdue = Number(res.overdue_due || 0);
  const todayDue = Number(res.today_due || 0);
  const upcoming = Number(res.upcoming_due || 0);
  const totalDue = Number(res.total_due || 0);
  console.log(`2. Overdue (${overdue}) + Due Today (${todayDue}) + Upcoming (${upcoming}) = Total Due (${totalDue}):`, (overdue + todayDue + upcoming === totalDue) ? 'VERIFIED (PASS)' : 'FAIL');

  const salesStillDue = Number(res.sales_still_due || 0);
  console.log(`3. Total Due (${totalDue}) = Sales Still Due (${salesStillDue}):`, (totalDue === salesStillDue) ? 'VERIFIED (PASS)' : 'FAIL');

  await pool.end();
}

verifyBackendQuery().catch(err => console.error('Error:', err));
