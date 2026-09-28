import { Router } from "express";
import { pool } from "../db.js";
import { toNum, ensureItemMaster } from "./helpers.js";

export function createPurchaseRouter(table) {
  const router = Router();
  const mapOut = (row) => {
    const r = toNum(row, ["qty", "rate", "amount", "quantity_value"]);
    return {
      ...r,
      specification: r.specification || "",
      quantity_unit: r.quantity_unit || "Kg",
      quantity_value: (r.quantity_value && Number(r.quantity_value) !== 0) ? r.quantity_value : r.qty
    };
  };

  router.get("/", async (_req,res)=>{
    try { const {rows}=await pool.query(`SELECT * FROM ${table} ORDER BY date DESC, created_at DESC`); res.json(rows.map(mapOut)); }
    catch(err){console.error(err);res.status(500).json({error:`Failed to load ${table}`})}
  });

  router.get("/check-delete/:id", async (req, res) => {
    try {
      const found = await pool.query(`SELECT * FROM ${table} WHERE id=$1`, [req.params.id]);
      if (!found.rows.length) return res.json({ canDelete: false, reason: "Purchase record not found." });
      const p = found.rows[0];
      const linkedSales = await pool.query(`SELECT 1 FROM sales WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,''))) LIMIT 1`, [p.item, p.specification]);
      if (linkedSales.rows.length) return res.json({ canDelete: false, reason: "Sales exist for this item/specification. Deletion is blocked to protect stock accuracy." });
      const stock = await pool.query(`SELECT * FROM stock WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,'')))`, [p.item, p.specification]);
      if (!stock.rows.length || Number(stock.rows[0].qty) < Number(p.qty)) return res.json({ canDelete: false, reason: "Current stock is below the purchased quantity." });
      res.json({ canDelete: true, reason: "Safe to delete." });
    } catch (err) {
      res.status(500).json({ canDelete: false, reason: err.message });
    }
  });

  router.post("/", async(req,res)=>{
    const date=req.body.date||null, vendor=String(req.body.vendor||"").trim(), item=String(req.body.item||"").trim();
    const specification=String(req.body.specification||"").trim() || null;
    const quantity_value=Number(req.body.quantityValue ?? req.body.quantity_value ?? req.body.qty);
    const quantity_unit=String(req.body.quantityUnit ?? req.body.quantity_unit ?? "Kg").trim();
    const rate=Number(req.body.rate);

    if(!date) return res.status(400).json({error:"Date is required"});
    if(!vendor) return res.status(400).json({error:"Vendor is required"});
    if(!item) return res.status(400).json({error:"Item is required"});
    if(!Number.isFinite(quantity_value) || quantity_value <= 0) return res.status(400).json({error:"Quantity must be greater than 0"});
    if(!Number.isFinite(rate) || rate < 0) return res.status(400).json({error:"Rate cannot be negative"});

    const client=await pool.connect();
    try{
      await client.query("BEGIN");
      await ensureItemMaster(client, item, specification);
      const unit=await client.query("SELECT kg_multiplier FROM unit_master WHERE lower(trim(name))=lower(trim($1)) OR lower(trim(symbol))=lower(trim($1)) LIMIT 1",[quantity_unit]);
      if(!unit.rows.length) throw new Error(`Unknown quantity unit: ${quantity_unit}. Add it in Master Settings.`);
      const multiplier=Number(unit.rows[0].kg_multiplier), qty=Number((quantity_value*multiplier).toFixed(3)), amount=Number((qty*rate).toFixed(2));
      const inserted=await client.query(`INSERT INTO ${table}(date,vendor,item,specification,qty,quantity_value,quantity_unit,rate,amount) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,[date,vendor,item,specification,qty,quantity_value,quantity_unit,rate,amount]);

      // Record stock movement
      await client.query(
        `INSERT INTO stock_movements (item, specification, qty_change, unit_cost, source_type, source_id, movement_date)
         VALUES ($1, $2, $3, $4, 'purchase', $5, $6)`,
        [item, specification, qty, rate, inserted.rows[0].id, date]
      );

      const stock=await client.query(`SELECT * FROM stock WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,''))) FOR UPDATE`,[item,specification]);
      if(stock.rows.length){
        const s=stock.rows[0], newQty=Number(s.qty)+qty, newAvg=((Number(s.qty)*Number(s.avg_cost))+amount)/newQty;
        await client.query(`UPDATE stock SET qty=$1,avg_cost=$2,updated_at=now() WHERE id=$3`,[newQty,newAvg,s.id]);
      } else {
        await client.query(`INSERT INTO stock(item,specification,qty,avg_cost,selling_price,status) VALUES($1,$2,$3,$4,0,'Available')`,[item,specification,qty,rate]);
      }
      await client.query("COMMIT"); res.status(201).json(mapOut(inserted.rows[0]));
    }catch(err){await client.query("ROLLBACK");console.error(err);res.status(400).json({error:err.message||"Purchase could not be saved"})}finally{client.release()}
  });

  router.patch("/:id", async (req, res) => {
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      const found = await client.query(`SELECT * FROM ${table} WHERE id=$1 FOR UPDATE`, [req.params.id]);
      if (!found.rows.length) throw new Error("Purchase not found");

      const old = found.rows[0];
      const date = req.body.date || old.date;
      const vendor = String(req.body.vendor || old.vendor).trim();
      const item = String(req.body.item || old.item).trim();
      const specification = req.body.specification !== undefined ? (String(req.body.specification || "").trim() || null) : old.specification;
      const quantity_value = Number(req.body.quantityValue ?? req.body.quantity_value ?? old.quantity_value ?? old.qty);
      const quantity_unit = String(req.body.quantityUnit ?? req.body.quantity_unit ?? old.quantity_unit ?? "Kg").trim();
      const rate = Number(req.body.rate ?? old.rate);

      if (!date || !vendor || !item || !Number.isFinite(quantity_value) || quantity_value <= 0 || !Number.isFinite(rate) || rate < 0) {
        throw new Error("Invalid purchase values");
      }

      // If item/spec changed, we must check if old stock can be reversed and new item exists
      // For simplicity, we reverse old then apply new.
      const unit = await client.query("SELECT kg_multiplier FROM unit_master WHERE lower(trim(name))=lower(trim($1)) OR lower(trim(symbol))=lower(trim($1)) LIMIT 1", [quantity_unit]);
      if (!unit.rows.length) throw new Error(`Unknown quantity unit: ${quantity_unit}`);
      const multiplier = Number(unit.rows[0].kg_multiplier), qty = Number((quantity_value * multiplier).toFixed(3)), amount = Number((qty * rate).toFixed(2));

      // 1. Reverse old stock effect
      const oldStock = await client.query(`SELECT * FROM stock WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,''))) FOR UPDATE`, [old.item, old.specification]);
      if (!oldStock.rows.length || Number(oldStock.rows[0].qty) < Number(old.qty)) throw new Error("Cannot edit purchase: stock already used/reduced below this quantity.");

      const sOld = oldStock.rows[0];
      const revQty = Number(sOld.qty) - Number(old.qty);
      // New average cost after reversal: (TotalVal - ThisVal) / NewQty
      const revAvg = revQty > 0 ? ( (Number(sOld.qty)*Number(sOld.avg_cost)) - Number(old.amount) ) / revQty : Number(sOld.avg_cost);
      await client.query(`UPDATE stock SET qty=$1, avg_cost=$2, updated_at=now() WHERE id=$3`, [revQty, revAvg, sOld.id]);

      // 2. Apply new stock effect
      await ensureItemMaster(client, item, specification);
      const newStock = await client.query(`SELECT * FROM stock WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,''))) FOR UPDATE`, [item, specification]);
      if (newStock.rows.length) {
        const sNew = newStock.rows[0], updQty = Number(sNew.qty) + qty, updAvg = ((Number(sNew.qty) * Number(sNew.avg_cost)) + amount) / updQty;
        await client.query(`UPDATE stock SET qty=$1, avg_cost=$2, updated_at=now() WHERE id=$3`, [updQty, updAvg, sNew.id]);
      } else {
        await client.query(`INSERT INTO stock(item,specification,qty,avg_cost,selling_price,status) VALUES($1,$2,$3,$4,0,'Available')`, [item, specification, qty, rate]);
      }

      // 3. Update purchase record
      const updated = await client.query(`UPDATE ${table} SET date=$1, vendor=$2, item=$3, specification=$4, qty=$5, quantity_value=$6, quantity_unit=$7, rate=$8, amount=$9 WHERE id=$10 RETURNING *`,
        [date, vendor, item, specification, qty, quantity_value, quantity_unit, rate, amount, req.params.id]);

      await client.query("COMMIT");
      res.json(mapOut(updated.rows[0]));
    } catch (err) {
      await client.query("ROLLBACK");
      console.error(err);
      res.status(400).json({ error: err.message });
    } finally {
      client.release();
    }
  });

  router.delete("/:id",async(req,res)=>{
    const client=await pool.connect();
    try{
      await client.query("BEGIN");
      const found=await client.query(`SELECT * FROM ${table} WHERE id=$1 FOR UPDATE`,[req.params.id]);
      if(!found.rows.length){await client.query("ROLLBACK");return res.status(404).json({error:"Not found"})}
      const p=found.rows[0];
      const linkedSales=await client.query(`SELECT 1 FROM sales WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,''))) LIMIT 1`,[p.item,p.specification]);
      if(linkedSales.rows.length) throw new Error("This purchase cannot be deleted after sales for the same item/specification exist. This protects stock accuracy.");
      const stock=await client.query(`SELECT * FROM stock WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,''))) FOR UPDATE`,[p.item,p.specification]);
      if(!stock.rows.length||Number(stock.rows[0].qty)<Number(p.qty)) throw new Error("Cannot reverse purchase because current stock is already below the purchased quantity.");
      const s=stock.rows[0],newQty=Number(s.qty)-Number(p.qty);
      await client.query(`DELETE FROM ${table} WHERE id=$1`,[req.params.id]);
      await client.query(`UPDATE stock SET qty=$1,updated_at=now() WHERE id=$2`,[newQty,s.id]);
      await client.query("COMMIT");res.status(204).end();
    }catch(err){await client.query("ROLLBACK");console.error(err);res.status(400).json({error:err.message})}finally{client.release()}
  });
  return router;
}
