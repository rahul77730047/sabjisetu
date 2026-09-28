import { Router } from "express";
import { pool } from "../db.js";
import { syncCustomerDue } from "./helpers.js";

export const customersRouter = Router();

customersRouter.get('/', async (_req, res) => {
  try {
    const { rows } = await pool.query('SELECT id, name, phone, created_at FROM customers ORDER BY created_at DESC');
    const out = [];
    for (const r of rows) {
      const c = await syncCustomerDue(pool, r.id);
      if (c) out.push(c);
    }
    res.json(out);
  } catch(err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to load customers' });
  }
});

customersRouter.post('/', async (req, res) => {
  const name = String(req.body.name || '').trim();
  const phone = String(req.body.phone || '').trim();
  if (!name) return res.status(400).json({ error: 'Customer name is required' });
  try {
    const { rows } = await pool.query('INSERT INTO customers(name, phone) VALUES($1, $2) RETURNING *', [name, phone]);
    res.status(201).json({ ...rows[0], due: 0, business: 0, dueDate: null, status: 'Upcoming' });
  } catch(err) {
    res.status(400).json({ error: err.code === '23505' ? 'Customer already exists' : 'Failed to create customer' });
  }
});

customersRouter.patch('/:id', async (req, res) => {
  const { name, phone, due, business, due_date, status } = req.body;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const fields = [], vals = [];
    if (name !== undefined) { fields.push(`name=$${vals.length + 1}`); vals.push(String(name).trim()); }
    if (phone !== undefined) { fields.push(`phone=$${vals.length + 1}`); vals.push(String(phone).trim()); }
    if (due !== undefined) { fields.push(`due=$${vals.length + 1}`); vals.push(Number(due)); }
    if (business !== undefined) { fields.push(`business=$${vals.length + 1}`); vals.push(Number(business)); }
    if (due_date !== undefined) { fields.push(`due_date=$${vals.length + 1}`); vals.push(due_date || null); }
    if (status !== undefined) { fields.push(`status=$${vals.length + 1}`); vals.push(String(status).trim()); }

    if (fields.length === 0) throw new Error('Nothing to update');

    vals.push(req.params.id);
    const { rows } = await client.query(`UPDATE customers SET ${fields.join(',')} WHERE id=$${vals.length} RETURNING id`, vals);
    if (!rows.length) throw new Error('Customer not found');

    const out = await syncCustomerDue(client, req.params.id);
    await client.query('COMMIT');
    res.json(out);
  } catch(err) {
    await client.query('ROLLBACK');
    console.error("[customers/patch]", err);
    res.status(400).json({ error: err.message || 'Failed to update customer' });
  } finally {
    client.release();
  }
});

customersRouter.delete('/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM customers WHERE id=$1', [req.params.id]);
    res.status(204).end();
  } catch(err) {
    res.status(400).json({ error: 'Cannot delete customer with linked payments' });
  }
});
