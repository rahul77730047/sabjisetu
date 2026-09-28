import { Router } from "express";
import { pool } from "../db.js";
import { todayIST } from "./helpers.js";

export const reportsRouter = Router();

const n = (v) => Number(v || 0);

reportsRouter.get("/trend", async (_req, res) => {
  try {
    const today = todayIST();
    const { rows } = await pool.query(`
      WITH days AS (
        SELECT generate_series($1::date - INTERVAL '6 days', $1::date, INTERVAL '1 day')::date AS report_date
      ),
      s AS (SELECT date AS report_date, SUM(amount) AS total FROM sales GROUP BY date),
      p AS (
        SELECT date AS report_date, SUM(amount) AS total
        FROM (SELECT date, amount FROM mandi_purchases UNION ALL SELECT date, amount FROM local_purchases) x
        GROUP BY date
      )
      SELECT TO_CHAR(d.report_date,'DD Mon') AS report_day,
             COALESCE(s.total,0) AS sales,
             COALESCE(p.total,0) AS purchase
      FROM days d
      LEFT JOIN s ON s.report_date=d.report_date
      LEFT JOIN p ON p.report_date=d.report_date
      ORDER BY d.report_date;
    `, [today]);
    res.json(rows.map(r => ({ day:r.report_day, sales:n(r.sales), purchase:n(r.purchase) })));
  } catch (e) {
    console.error("[reports/trend]", e);
    if (!res.headersSent) res.status(500).json({error:"Failed to compute trend"});
  }
});

reportsRouter.get("/summary", async (_req, res) => {
  try {
    const today = todayIST();
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

        (SELECT json_build_object('item', item, 'qty', SUM(qty)) FROM sales WHERE date=$1::date GROUP BY item ORDER BY SUM(qty) DESC, item ASC LIMIT 1) AS top_selling_today,
        (SELECT json_agg(x) FROM (SELECT name, phone, due, status FROM customers WHERE due > 0 ORDER BY due DESC LIMIT 5) x) AS recent_dues,
        (SELECT json_agg(x) FROM (SELECT item, customer, amount FROM sales ORDER BY created_at DESC LIMIT 5) x) AS recent_sales,
        (SELECT json_agg(x) FROM (SELECT item, qty, status FROM stock WHERE qty <= (SELECT low_stock_threshold_kg FROM business_settings WHERE id=1) ORDER BY qty ASC LIMIT 5) x) AS stock_alerts,
        (SELECT json_agg(x) FROM (SELECT item, qty, avg_cost, selling_price, status FROM stock ORDER BY item ASC) x) AS stock_snapshot
    `, [today]);
    const r = rows[0];
    res.json(Object.fromEntries(Object.entries(r).map(([k,v])=>{
      if (Array.isArray(v) || (v && typeof v === 'object')) return [k, v];
      return [k, n(v)];
    })));
  } catch(e) {
    console.error("[reports/summary]",e);
    if (!res.headersSent) res.status(500).json({error:"Failed to compute summary"});
  }
});

// One canonical analytics endpoint. It powers date-wise, monthly, demand,
// profit and purchase-recommendation views without duplicating calculations.
reportsRouter.get("/overview", async (req, res) => {
  try {
    const today = todayIST();
    const from = req.query.from || `${today.slice(0,8)}01`;
    const to = req.query.to || today;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to) || from > to) {
      return res.status(400).json({error:"Invalid date range"});
    }
    const { rows } = await pool.query(`
      WITH sales_range AS (
        SELECT date, item, specification, qty, amount, cogs
        FROM sales WHERE date BETWEEN $1::date AND $2::date
      ),
      purchases_range AS (
        SELECT date, item, specification, qty, amount FROM mandi_purchases WHERE date BETWEEN $1::date AND $2::date
        UNION ALL
        SELECT date, item, specification, qty, amount FROM local_purchases WHERE date BETWEEN $1::date AND $2::date
      ),
      daily AS (
        SELECT d.day::date AS date,
          COALESCE((SELECT SUM(amount) FROM sales_range s WHERE s.date=d.day),0) AS sales,
          COALESCE((SELECT SUM(amount) FROM purchases_range p WHERE p.date=d.day),0) AS purchase,
          COALESCE((SELECT SUM(qty) FROM sales_range s WHERE s.date=d.day),0) AS sold_qty,
          COALESCE((SELECT SUM(cogs) FROM sales_range s WHERE s.date=d.day),0) AS cogs
        FROM generate_series($1::date,$2::date,INTERVAL '1 day') d(day)
      ),
      items AS (
        SELECT s.item, s.specification,
          SUM(s.qty) sold_qty,
          SUM(s.amount) revenue,
          SUM(s.cogs) cogs,
          SUM(s.amount-s.cogs) profit
        FROM sales_range s GROUP BY s.item, s.specification
      ),
      item_purchases AS (
        SELECT item, specification, SUM(qty) purchased_qty, SUM(amount) purchase_amount
        FROM purchases_range GROUP BY item, specification
      ),
      stock_by_item AS (
        SELECT sm.item, sm.specification,
               SUM(sm.qty_change) stock_qty,
               CASE WHEN SUM(CASE WHEN sm.qty_change > 0 THEN sm.qty_change ELSE 0 END)=0 THEN 0
                    ELSE SUM(CASE WHEN sm.qty_change > 0 THEN sm.qty_change * sm.unit_cost ELSE 0 END)
                         / SUM(CASE WHEN sm.qty_change > 0 THEN sm.qty_change ELSE 0 END) END AS avg_cost,
               COALESCE((SELECT MAX(st.selling_price) FROM stock st
                         WHERE lower(trim(st.item))=lower(trim(sm.item))
                           AND lower(trim(coalesce(st.specification,'')))=lower(trim(coalesce(sm.specification,'')))),0) AS selling_price
        FROM stock_movements sm
        WHERE sm.movement_date <= $2::date
        GROUP BY sm.item, sm.specification
      )
      SELECT
        (SELECT COALESCE(json_agg(d ORDER BY d.date),'[]'::json) FROM daily d) AS daily,
        (SELECT COALESCE(json_agg(i ORDER BY i.profit DESC),'[]'::json)
           FROM (SELECT i.*, COALESCE(p.purchased_qty,0) purchased_qty, COALESCE(p.purchase_amount,0) purchase_amount,
                        COALESCE(st.stock_qty,0) stock_qty, COALESCE(st.avg_cost,0) avg_cost, COALESCE(st.selling_price,0) selling_price
                 FROM items i
                 LEFT JOIN item_purchases p ON lower(trim(p.item))=lower(trim(i.item))
                   AND lower(trim(coalesce(p.specification,'')))=lower(trim(coalesce(i.specification,'')))
                 LEFT JOIN stock_by_item st ON lower(trim(st.item))=lower(trim(i.item))
                   AND lower(trim(coalesce(st.specification,'')))=lower(trim(coalesce(i.specification,'')))) i) AS items,
        (SELECT json_build_object(
          'sales',COALESCE(SUM(sales),0),'purchase',COALESCE(SUM(purchase),0),
          'sold_qty',COALESCE(SUM(sold_qty),0),'cogs',COALESCE(SUM(cogs),0),
          'profit',COALESCE(SUM(sales-cogs),0)
        ) FROM daily) AS totals;
    `,[from,to]);
    const raw=rows[0];
    const daily=(raw.daily||[]).map(d=>({...d,sales:n(d.sales),purchase:n(d.purchase),sold_qty:n(d.sold_qty),cogs:n(d.cogs),profit:n(d.sales)-n(d.cogs)}));
    const days=Math.max(1,Math.round((new Date(to)-new Date(from))/86400000)+1);
    const items=(raw.items||[]).map(i=>{
      const sold=n(i.sold_qty), revenue=n(i.revenue), cogs=n(i.cogs), profit=n(i.profit), stock=n(i.stock_qty);
      const avgDaily=sold/days, margin=revenue?profit/revenue*100:0;
      const coverage=avgDaily>0?stock/avgDaily:null;
      let recommendation="Hold";
      let priority="NORMAL";
      let suggested=0;
      if(stock<=0 && avgDaily>0){recommendation="Purchase now";priority="URGENT";suggested=Math.ceil(avgDaily*7);}
      else if(coverage!==null && coverage<3){recommendation="Purchase now";priority="URGENT";suggested=Math.ceil(Math.max(0,avgDaily*7-stock));}
      else if(coverage!==null && coverage<7){recommendation="Purchase soon";priority="HIGH";suggested=Math.ceil(Math.max(0,avgDaily*7-stock));}
      else if(margin>=20 && avgDaily>0 && coverage<14){recommendation="Good next purchase";priority="MEDIUM";suggested=Math.ceil(Math.max(0,avgDaily*7-stock));}
      return {...i,sold_qty:sold,revenue,cogs,profit,stock_qty:stock,avg_cost:n(i.avg_cost),selling_price:n(i.selling_price),margin:Number(margin.toFixed(1)),avg_daily_qty:Number(avgDaily.toFixed(2)),stock_days:coverage===null?null:Number(coverage.toFixed(1)),recommendation,priority,suggested_qty:suggested};
    });
    const totals=raw.totals||{};
    res.json({from,to,days,daily,items,totals:{sales:n(totals.sales),purchase:n(totals.purchase),sold_qty:n(totals.sold_qty),cogs:n(totals.cogs),profit:n(totals.profit)}});
  } catch(e) {
    console.error("[reports/overview]",e);
    if (!res.headersSent) res.status(500).json({error:"Failed to compute analytics"});
  }
});
