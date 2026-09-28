import { Router } from "express";
import { pool } from "../db.js";

export const mastersRouter = Router();

mastersRouter.get("/", async (_req, res) => {
  try {
    // Self-heal the master list from every transaction source. This is important
    // for vegetables that were already entered before the auto-sync feature was added.
    // It also guarantees that the Sales/Purchase autocomplete always has every
    // real item present in the database.
    await pool.query(`
      INSERT INTO item_master(name_en, name_hi, active)
      SELECT DISTINCT trim(item), '', true
      FROM (
        SELECT item FROM stock
        UNION ALL SELECT item FROM mandi_purchases
        UNION ALL SELECT item FROM local_purchases
        UNION ALL SELECT item FROM sales
      ) x
      WHERE trim(coalesce(item, '')) <> ''
      ON CONFLICT ((lower(trim(name_en))))
      DO UPDATE SET name_en = item_master.name_en
    `);

    await pool.query(`
      INSERT INTO item_specifications(item_id, name, active)
      SELECT im.id, trim(x.specification), true
      FROM item_master im
      JOIN (
        SELECT DISTINCT item, specification FROM stock
        UNION ALL SELECT DISTINCT item, specification FROM mandi_purchases
        UNION ALL SELECT DISTINCT item, specification FROM local_purchases
        UNION ALL SELECT DISTINCT item, specification FROM sales
      ) x ON lower(trim(x.item)) = lower(trim(im.name_en))
      WHERE trim(coalesce(x.specification, '')) <> ''
      ON CONFLICT DO NOTHING
    `);

    const [items, specs, units, vendors, expenses, customers] = await Promise.all([
      pool.query("SELECT * FROM item_master ORDER BY name_en"),
      pool.query("SELECT s.*, i.name_en AS item_name FROM item_specifications s JOIN item_master i ON i.id=s.item_id ORDER BY i.name_en,s.name"),
      pool.query("SELECT * FROM unit_master ORDER BY id"),
      pool.query("SELECT * FROM vendor_master ORDER BY name"),
      pool.query("SELECT * FROM expense_category_master ORDER BY name"),
      pool.query("SELECT id, name FROM customers ORDER BY name"),
    ]);
    const specMap = {};
    for (const s of specs.rows) (specMap[s.item_id] ||= []).push({ id:s.id, name:s.name });
    res.json({
      items: items.rows.map(i => ({
        id: i.id,
        name_en: i.name_en,
        nameEn: i.name_en,
        name_hi: i.name_hi,
        nameHi: i.name_hi,
        active: i.active,
        specifications: specMap[i.id] || []
      })),
      units: units.rows.map(u => ({
        id: u.id,
        name: u.name,
        symbol: u.symbol,
        active: u.active,
        kg_multiplier: Number(u.kg_multiplier),
        kgMultiplier: Number(u.kg_multiplier)
      })),
      vendors: vendors.rows.map(v => ({
        id: v.id,
        name: v.name,
        active: v.active,
        vendor_type: v.vendor_type,
        type: v.vendor_type
      })),
      expenseCategories: expenses.rows.map(e => ({
        id: e.id,
        name: e.name,
        active: e.active
      })),
      customers: customers.rows.map(c => ({ id: c.id, name: c.name })),
    });
  } catch (e) { console.error(e); res.status(500).json({ error:"Failed to load masters" }); }
});

mastersRouter.post("/items", async (req,res)=>{
  const name_en=String(req.body.name_en ?? req.body.nameEn ?? "").trim();
  const name_hi=String(req.body.name_hi ?? req.body.nameHi ?? "").trim();
  const specifications=Array.isArray(req.body.specifications)?req.body.specifications.map(x=>String(x).trim()).filter(Boolean):[];
  if(!name_en) return res.status(400).json({error:"English item name is required"});
  const client=await pool.connect();
  try{await client.query("BEGIN");
    const {rows}=await client.query(`INSERT INTO item_master(name_en,name_hi) VALUES($1,$2) ON CONFLICT ((lower(trim(name_en)))) DO UPDATE SET name_hi=EXCLUDED.name_hi,active=true RETURNING *`,[name_en,name_hi]);
    const seenSpecs = new Set();
    for (const spec of specifications) {
      const key = spec.toLowerCase();
      if (seenSpecs.has(key)) continue;
      seenSpecs.add(key);
      await client.query(`INSERT INTO item_specifications(item_id,name) VALUES($1,$2) ON CONFLICT DO NOTHING`,[rows[0].id, spec]);
    }
    await client.query("COMMIT"); res.status(201).json(rows[0]);
  }catch(e){await client.query("ROLLBACK");console.error(e);res.status(400).json({error:"Failed to save item master"})}finally{client.release()}
});

mastersRouter.patch("/items/:id", async(req,res)=>{
  const fields=[]; const vals=[];
  const name_en = req.body.name_en ?? req.body.nameEn;
  const name_hi = req.body.name_hi ?? req.body.nameHi;

  if(name_en!==undefined){fields.push(`name_en=$${vals.length+1}`);vals.push(String(name_en).trim())}
  if(name_hi!==undefined){fields.push(`name_hi=$${vals.length+1}`);vals.push(String(name_hi).trim())}
  if(req.body.active!==undefined){fields.push(`active=$${vals.length+1}`);vals.push(Boolean(req.body.active))}
  if(!fields.length)return res.status(400).json({error:"Nothing to update"});
  vals.push(req.params.id);
  try{const {rows}=await pool.query(`UPDATE item_master SET ${fields.join(',')} WHERE id=$${vals.length} RETURNING *`,vals);if(!rows.length)return res.status(404).json({error:"Item not found"});res.json(rows[0])}catch(e){res.status(400).json({error:"Failed to update item master"})}
});

mastersRouter.post("/items/:id/specifications", async(req,res)=>{const name=String(req.body.name||"").trim();if(!name)return res.status(400).json({error:"Specification is required"});try{const {rows}=await pool.query(`INSERT INTO item_specifications(item_id,name) VALUES($1,$2) ON CONFLICT DO NOTHING RETURNING *`,[req.params.id,name]);res.status(201).json(rows[0]||{name})}catch(e){res.status(400).json({error:"Failed to save specification"})}});
mastersRouter.delete("/specifications/:id",async(req,res)=>{try{await pool.query("UPDATE item_specifications SET active=false WHERE id=$1",[req.params.id]);res.status(204).end()}catch(e){res.status(400).json({error:"Failed to delete specification"})}});

async function simpleMaster(req,res,table,fields){
  const name=String(req.body.name||"").trim(); if(!name)return res.status(400).json({error:"Name is required"});
  try{const extra=table==='unit_master'?[String(req.body.symbol||name).trim(),Number(req.body.kg_multiplier)]:table==='vendor_master'?[String(req.body.vendor_type||'Both')]:[];
    if(table==='unit_master' && (!Number.isFinite(extra[1])||extra[1]<=0)) return res.status(400).json({error:"Invalid kg conversion"});
    let q,vals;
    if(table==='unit_master'){q=`INSERT INTO unit_master(name,symbol,kg_multiplier) VALUES($1,$2,$3) ON CONFLICT ((lower(trim(name)))) DO UPDATE SET symbol=EXCLUDED.symbol,kg_multiplier=EXCLUDED.kg_multiplier,active=true RETURNING *`;vals=[name,...extra]}
    else if(table==='vendor_master'){q=`INSERT INTO vendor_master(name,vendor_type) VALUES($1,$2) ON CONFLICT ((lower(trim(name)))) DO UPDATE SET vendor_type=EXCLUDED.vendor_type,active=true RETURNING *`;vals=[name,...extra]}
    else {q=`INSERT INTO expense_category_master(name) VALUES($1) ON CONFLICT ((lower(trim(name)))) DO UPDATE SET active=true RETURNING *`;vals=[name]}
    const {rows}=await pool.query(q,vals);res.status(201).json(rows[0]);
  }catch(e){console.error(e);res.status(400).json({error:"Failed to save master"})}
}
mastersRouter.post("/units",(req,res)=>simpleMaster(req,res,"unit_master"));
mastersRouter.post("/vendors",(req,res)=>simpleMaster(req,res,"vendor_master"));
mastersRouter.post("/expense-categories",(req,res)=>simpleMaster(req,res,"expense_category_master"));

mastersRouter.patch("/units/:id", async (req, res) => {
  if (req.body.active === undefined) return res.status(400).json({ error: "Nothing to update" });
  try {
    const { rows } = await pool.query("UPDATE unit_master SET active=$1 WHERE id=$2 RETURNING *", [Boolean(req.body.active), req.params.id]);
    res.json(rows[0]);
  } catch (e) { res.status(400).json({ error: "Failed to update unit" }); }
});

mastersRouter.patch("/vendors/:id", async (req, res) => {
  if (req.body.active === undefined) return res.status(400).json({ error: "Nothing to update" });
  try {
    const { rows } = await pool.query("UPDATE vendor_master SET active=$1 WHERE id=$2 RETURNING *", [Boolean(req.body.active), req.params.id]);
    res.json(rows[0]);
  } catch (e) { res.status(400).json({ error: "Failed to update vendor" }); }
});

mastersRouter.patch("/expense-categories/:id", async (req, res) => {
  if (req.body.active === undefined) return res.status(400).json({ error: "Nothing to update" });
  try {
    const { rows } = await pool.query("UPDATE expense_category_master SET active=$1 WHERE id=$2 RETURNING *", [Boolean(req.body.active), req.params.id]);
    res.json(rows[0]);
  } catch (e) { res.status(400).json({ error: "Failed to update category" }); }
});
