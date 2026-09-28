import { Router } from "express";
import { pool } from "../db.js";

/**
 * Builds a basic REST router for a simple table:
 *   GET    /            -> list all rows
 *   POST   /            -> insert a row, returns the created row
 *   PATCH  /:id         -> partial update, returns the updated row
 *   DELETE /:id         -> delete a row
 *
 * `columns` lists the insertable/updatable column names (snake_case,
 * matching the database). The frontend sends camelCase keys like
 * "workType" or "sellingPrice" — `mapIn` translates those to the
 * snake_case column names the SQL uses, and `mapOut` translates rows
 * back to camelCase before they go to the browser.
 */
export function createCrudRouter({ table, columns, orderBy = "created_at DESC", mapIn = (x) => x, mapOut = (x) => x }) {
  const router = Router();

  router.get("/", async (_req, res) => {
    try {
      const { rows } = await pool.query(`SELECT * FROM ${table} ORDER BY ${orderBy}`);
      res.json(rows.map(mapOut));
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: "Failed to load " + table });
    }
  });

  router.post("/", async (req, res) => {
    try {
      const body = mapIn(req.body);
      const cols = columns.filter((c) => body[c] !== undefined);
      const values = cols.map((c) => body[c]);
      const placeholders = cols.map((_, i) => `$${i + 1}`).join(", ");
      const { rows } = await pool.query(
        `INSERT INTO ${table} (${cols.join(", ")}) VALUES (${placeholders}) RETURNING *`,
        values
      );
      res.status(201).json(mapOut(rows[0]));
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: "Failed to create " + table + " row" });
    }
  });

  router.patch("/:id", async (req, res) => {
    try {
      const body = mapIn(req.body);
      const cols = columns.filter((c) => body[c] !== undefined);
      if (cols.length === 0) return res.status(400).json({ error: "No valid fields to update" });
      const setClause = cols.map((c, i) => `${c} = $${i + 1}`).join(", ");
      const values = cols.map((c) => body[c]);
      const { rows } = await pool.query(
        `UPDATE ${table} SET ${setClause} WHERE id = $${cols.length + 1} RETURNING *`,
        [...values, req.params.id]
      );
      if (rows.length === 0) return res.status(404).json({ error: "Not found" });
      res.json(mapOut(rows[0]));
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: "Failed to update " + table + " row" });
    }
  });

  router.delete("/:id", async (req, res) => {
    try {
      await pool.query(`DELETE FROM ${table} WHERE id = $1`, [req.params.id]);
      res.status(204).end();
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: "Failed to delete " + table + " row" });
    }
  });

  return router;
}
