import { Router } from "express";
import { pool } from "../db.js";
import { toNum, ensureItemMaster } from "./helpers.js";

export const stockRouter = Router();

const mapOut = (row) => {
  const r = toNum(row, ["qty", "avg_cost", "selling_price"]);
  const avgCost = r.avg_cost !== undefined ? r.avg_cost : (r.avgCost !== undefined ? r.avgCost : 0);
  const sellingPrice = r.selling_price !== undefined ? r.selling_price : (r.sellingPrice !== undefined ? r.sellingPrice : 0);
  return {
    ...r,
    avg_cost: avgCost,
    avgCost: avgCost,
    selling_price: sellingPrice,
    sellingPrice: sellingPrice,
    quantity_value: r.qty,
    quantityValue: r.qty,
    specification: r.specification || "",
    status: r.status || "Available"
  };
};

stockRouter.get("/", async (_req, res) => {
  try {
    const { rows } = await pool.query("SELECT * FROM stock ORDER BY item ASC");
    res.json(rows.map(mapOut));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to load stock" });
  }
});

stockRouter.get("/movements", async (req, res) => {
  try {
    const { rows } = await pool.query("SELECT * FROM stock_movements ORDER BY movement_date DESC, created_at DESC LIMIT 200");
    res.json(rows.map(r => toNum(r, ["qty_change", "unit_cost"])));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to load stock movements" });
  }
});

// Manual opening/adjustment stock. Normal stock changes should come from purchases/sales.
stockRouter.post("/", async (req, res) => {
  const item = String(req.body.item || "").trim();
  const rawQty = req.body.qty !== undefined ? req.body.qty : (req.body.quantity_value ?? req.body.quantityValue);
  const qty = Number(rawQty || 0);
  const rawAvgCost = req.body.avg_cost !== undefined ? req.body.avg_cost : req.body.avgCost;
  const avg_cost = Number(rawAvgCost || 0);
  const rawSellingPrice = req.body.selling_price !== undefined ? req.body.selling_price : req.body.sellingPrice;
  const selling_price = Number(rawSellingPrice || 0);
  const specification = String(req.body.specification || "").trim() || null;
  const quantity_unit = String(req.body.quantity_unit || req.body.quantityUnit || "Kg").trim();
  const quantity_value = Number(req.body.quantity_value ?? req.body.quantityValue ?? qty);
  const status = String(req.body.status || "Available").trim() || "Available";

  if (!item) return res.status(400).json({ error: "Item is required" });
  if (!Number.isFinite(quantity_value)) return res.status(400).json({ error: "Invalid quantity" });
  if (!Number.isFinite(avg_cost) || avg_cost < 0) return res.status(400).json({ error: "Invalid average cost" });
  if (!Number.isFinite(selling_price) || selling_price < 0) return res.status(400).json({ error: "Invalid selling price" });

  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    // Register manually entered vegetables in Item Master immediately.
    await ensureItemMaster(client, item, specification);
    const unitResult = await client.query("SELECT kg_multiplier FROM unit_master WHERE lower(trim(name))=lower(trim($1)) OR lower(trim(symbol))=lower(trim($1)) LIMIT 1", [quantity_unit]);
    if (!unitResult.rows.length) return res.status(400).json({ error: `Unknown quantity unit: ${quantity_unit}` });
    const normalizedQty = Number((quantity_value * Number(unitResult.rows[0].kg_multiplier)).toFixed(3));
    const { rows } = await client.query(
      `INSERT INTO stock (item, specification, qty, avg_cost, selling_price, status)
       VALUES ($1,$2,$3,$4,$5,$6)
       ON CONFLICT ((lower(trim(item))), (lower(trim(coalesce(specification,''))))) DO UPDATE
       SET qty = stock.qty + EXCLUDED.qty,
           avg_cost = CASE WHEN stock.qty + EXCLUDED.qty = 0 THEN 0
                           ELSE ((stock.qty * stock.avg_cost) + (EXCLUDED.qty * EXCLUDED.avg_cost)) / (stock.qty + EXCLUDED.qty) END,
           selling_price = CASE WHEN EXCLUDED.selling_price > 0 THEN EXCLUDED.selling_price ELSE stock.selling_price END,
           updated_at = now()
       RETURNING *`,
      [item, specification, normalizedQty, avg_cost, selling_price, status]
    );

    // Record movement
    await client.query(
      `INSERT INTO stock_movements (item, specification, qty_change, unit_cost, source_type, movement_date)
       VALUES ($1, $2, $3, $4, 'manual', CURRENT_DATE)`,
      [item, specification, normalizedQty, avg_cost]
    );

    await client.query("COMMIT");
    res.status(201).json(mapOut(rows[0]));
  } catch (err) {
    await client.query("ROLLBACK");
    console.error(err);
    res.status(500).json({ error: "Failed to save stock" });
  } finally { client.release(); }
});

stockRouter.patch("/:id", async (req, res) => {
  const { id } = req.params;
  const { item, specification, status } = req.body;
  const rawQty = req.body.qty !== undefined ? req.body.qty : (req.body.quantity_value ?? req.body.quantityValue);
  const rawAvgCost = req.body.avg_cost !== undefined ? req.body.avg_cost : req.body.avgCost;
  const rawSellingPrice = req.body.selling_price !== undefined ? req.body.selling_price : req.body.sellingPrice;

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // Check if record exists
    const check = await client.query("SELECT * FROM stock WHERE id = $1 FOR UPDATE", [id]);
    if (check.rows.length === 0) throw new Error("Stock record not found.");

    const updFields = [];
    const updVals = [];

    if (item !== undefined) { updFields.push(`item = $${updVals.length+1}`); updVals.push(String(item).trim()); }
    if (specification !== undefined) { updFields.push(`specification = $${updVals.length+1}`); updVals.push(specification ? String(specification).trim() : null); }
    if (rawQty !== undefined) { updFields.push(`qty = $${updVals.length+1}`); updVals.push(Number(rawQty)); }
    if (rawAvgCost !== undefined) { updFields.push(`avg_cost = $${updVals.length+1}`); updVals.push(Number(rawAvgCost)); }
    if (rawSellingPrice !== undefined) { updFields.push(`selling_price = $${updVals.length+1}`); updVals.push(Number(rawSellingPrice)); }
    if (status !== undefined) { updFields.push(`status = $${updVals.length+1}`); updVals.push(String(status).trim() || "Available"); }

    if (updFields.length > 0) {
      updVals.push(id);
      const { rows } = await client.query(
        `UPDATE stock SET ${updFields.join(", ")}, updated_at = now() WHERE id = $${updVals.length} RETURNING *`,
        updVals
      );
      await client.query("COMMIT");
      res.json(mapOut(rows[0]));
    } else {
      res.status(400).json({ error: "Nothing to update" });
    }
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("[stock/patch]", err);
    res.status(400).json({ error: err.message || "Failed to update stock" });
  } finally {
    client.release();
  }
});

stockRouter.get("/check-delete/:id", async (req, res) => {
  try {
    const { rows } = await pool.query(`SELECT s.id, s.qty, s.item, s.specification FROM stock s WHERE s.id=$1`, [req.params.id]);
    if (!rows.length) return res.json({ canDelete: false, reason: "Stock record not found." });
    const item = rows[0];
    const { rows: usage } = await pool.query(`
      SELECT 1 FROM sales WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,'')))
      UNION ALL
      SELECT 1 FROM mandi_purchases WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,'')))
      UNION ALL
      SELECT 1 FROM local_purchases WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,'')))
      LIMIT 1
    `, [item.item, item.specification]);

    if (usage.length > 0) {
      return res.json({ canDelete: false, reason: `Stock record for '${item.item}' is linked to transaction history and cannot be deleted.` });
    }
    res.json({ canDelete: true, reason: "Safe to delete." });
  } catch (err) {
    res.status(500).json({ canDelete: false, reason: err.message });
  }
});

stockRouter.delete("/:id", async (req,res)=>{
  try {
    const {rows}=await pool.query(`SELECT s.id,s.qty, s.item, s.specification FROM stock s WHERE s.id=$1`,[req.params.id]);
    if(!rows.length)return res.status(404).json({error:"Not found"});

    const item = rows[0];
    const { rows: usage } = await pool.query(`
      SELECT 1 FROM sales WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,'')))
      UNION ALL
      SELECT 1 FROM mandi_purchases WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,'')))
      UNION ALL
      SELECT 1 FROM local_purchases WHERE lower(trim(item))=lower(trim($1)) AND lower(trim(coalesce(specification,'')))=lower(trim(coalesce($2,'')))
      LIMIT 1
    `, [item.item, item.specification]);

    if (usage.length > 0) {
      return res.status(400).json({ error: `Delete stock record for ${item.item}? This is allowed only when it has no purchase/sale history.` });
    }

    await pool.query("DELETE FROM stock WHERE id=$1",[req.params.id]);
    res.status(204).end();
  } catch(err){
    console.error("[stock/delete]", err);
    res.status(400).json({error: "Failed to delete stock. Record might be linked to other data."});
  }
});
