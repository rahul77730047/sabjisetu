import { Router } from "express";
import { pool } from "../db.js";
import { todayIST, syncCustomerDue, toNum } from "./helpers.js";

export const paymentsRouter = Router();

paymentsRouter.get("/", async (_req, res) => {
  try {
    const { rows: payments } = await pool.query(`
      SELECT p.id, p.date, COALESCE(c.name, 'Unknown') AS customer, c.phone, p.amount, p.note, p.payment_method, p.payment_proof, p.transaction_id, p.customer_id, 'Payment' AS type, p.created_at
      FROM customer_payments p
      LEFT JOIN customers c ON c.id = p.customer_id
      ORDER BY p.date DESC, p.created_at DESC
    `);

    const { rows: sales } = await pool.query(`
      SELECT s.id, s.date, s.customer, c.phone, s.amount, 'Due Bill: '||s.item AS note, s.payment_method, s.payment_proof, s.transaction_id, c.id AS customer_id, 'Due' AS type, s.created_at
      FROM sales s
      LEFT JOIN customers c ON lower(trim(c.name)) = lower(trim(s.customer))
      WHERE s.status = 'Due'
      ORDER BY s.date ASC, s.created_at ASC
    `);

    // Group total payments by customer name (trimmed, lowercased)
    const customerPayments = {};
    for (const p of payments) {
      const ckey = (p.customer || "").trim().toLowerCase();
      customerPayments[ckey] = (customerPayments[ckey] || 0) + Number(p.amount || 0);
    }

    // Allocate customer payments against due sales in FIFO chronological order
    const remainingDueSales = [];
    const runningPayments = { ...customerPayments };

    for (const s of sales) {
      const ckey = (s.customer || "").trim().toLowerCase();
      const saleAmt = Number(s.amount || 0);
      const availPayment = runningPayments[ckey] || 0;

      if (availPayment >= saleAmt) {
        // Sale is fully covered by accumulated payments
        runningPayments[ckey] = availPayment - saleAmt;
      } else {
        // Sale is partially covered or unpaid
        const unpaidPart = saleAmt - availPayment;
        runningPayments[ckey] = 0;
        remainingDueSales.push({
          ...s,
          amount: Number(unpaidPart.toFixed(2)),
        });
      }
    }

    // Combine payments and remaining due sales, sorted by date DESC, created_at DESC
    const combined = [...payments, ...remainingDueSales];
    combined.sort((a, b) => {
      const dA = (a.date || '').toString();
      const dB = (b.date || '').toString();
      if (dA !== dB) return dB.localeCompare(dA);
      return (b.created_at || '').toString().localeCompare((a.created_at || '').toString());
    });

    res.json(combined.map(r => toNum(r, ["amount"])));
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Failed to load payments" });
  }
});

paymentsRouter.post("/", async (req, res) => {
  let customer_id = req.body.customer_id;
  const customer_name = String(req.body.customer || "").trim();
  const date = req.body.date || todayIST();
  const amount = Number(req.body.amount);
  const note = String(req.body.note || "");
  const payment_method = String(req.body.payment_method || "Cash").trim();
  const transaction_id = String(req.body.transaction_id || "").trim();
  const payment_proof = String(req.body.payment_proof || "").trim();

  if (!customer_id && !customer_name) return res.status(400).json({ error: "Customer is required" });
  if (!date) return res.status(400).json({ error: "Date is required" });
  if (!Number.isFinite(amount) || amount <= 0) return res.status(400).json({ error: "Amount must be greater than 0" });

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    if (!customer_id && customer_name) {
      const custResult = await client.query("SELECT id, name, phone FROM customers WHERE lower(trim(name)) = lower(trim($1))", [customer_name]);
      if (custResult.rows.length) {
        customer_id = custResult.rows[0].id;
      } else {
        throw new Error(`Customer '${customer_name}' not found. Please add them in Customers first.`);
      }
    }

    const customer = await client.query(
      "SELECT id, name, phone FROM customers WHERE id=$1 FOR UPDATE",
      [customer_id]
    );
    if (!customer.rows.length) throw new Error("Customer not found.");
    const customer_name_real = customer.rows[0].name;
    const customer_phone = customer.rows[0].phone || "";

    // Calculate current customer outstanding due
    const dueResult = await client.query(
      `SELECT GREATEST(
         0,
         COALESCE((SELECT SUM(amount) FROM sales WHERE lower(trim(customer))=lower(trim($1)) AND status='Due'),0)
         - COALESCE((SELECT SUM(amount) FROM customer_payments WHERE customer_id=$2 OR customer_id IN (SELECT id FROM customers WHERE lower(trim(name))=lower(trim($1)))),0)
       ) AS due`,
      [customer_name_real, customer_id]
    );

    const currentDue = Number(dueResult.rows[0]?.due || 0);
    if (amount > currentDue + 0.005) {
      throw new Error(`Payment exceeds current due of ₹${currentDue.toLocaleString('en-IN')}`);
    }

    // Insert payment record into customer_payments
    const { rows } = await client.query(
      `INSERT INTO customer_payments(customer_id,date,amount,note,payment_method,transaction_id,payment_proof)
       VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [customer_id, date, amount, note, payment_method, transaction_id, payment_proof]
    );

    const paymentId = rows[0].id;

    // Automatically log payment entry in whatsapp_bills audit table
    await client.query(
      `INSERT INTO whatsapp_bills (customer, phone, amount, date, status, kind, message, payment_method, payment_proof, source_payment_id)
       VALUES ($1, $2, $3, $4, 'Payment Recorded', 'Payment', $5, $6, $7, $8)`,
      [
        customer_name_real,
        customer_phone,
        amount,
        date,
        note || `Payment of ₹${amount} received via ${payment_method}`,
        payment_method,
        payment_proof,
        paymentId
      ]
    );

    // Sync customer due and status
    await syncCustomerDue(client, customer_id);

    await client.query("COMMIT");
    res.status(201).json(toNum(rows[0], ["amount"]));
  } catch (e) {
    await client.query("ROLLBACK");
    console.error(e);
    res.status(400).json({ error: e.message });
  } finally {
    client.release();
  }
});

paymentsRouter.patch("/:id", async (req, res) => {
  const { id } = req.params;
  const { phone, amount, note, date, payment_method, transaction_id, payment_proof } = req.body;
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // 1. Try to find in customer_payments table first
    const paymentCheck = await client.query("SELECT * FROM customer_payments WHERE id = $1 FOR UPDATE", [id]);

    if (paymentCheck.rows.length > 0) {
      const p = paymentCheck.rows[0];
      const newAmount = amount !== undefined ? Number(amount) : Number(p.amount);
      const newNote = note !== undefined ? String(note) : p.note;
      const newDate = date !== undefined ? date : p.date;
      const newMethod = payment_method !== undefined ? String(payment_method).trim() : p.payment_method;
      const newTx = transaction_id !== undefined ? String(transaction_id).trim() : p.transaction_id;
      const newProof = payment_proof !== undefined ? String(payment_proof).trim() : p.payment_proof;

      await client.query(
        "UPDATE customer_payments SET amount = $1, note = $2, date = $3, payment_method = $4, transaction_id = $5, payment_proof = $6 WHERE id = $7",
        [newAmount, newNote, newDate, newMethod, newTx, newProof, id]
      );

      // Also update linked whatsapp_bills audit log
      await client.query(
        "UPDATE whatsapp_bills SET amount = $1, date = $2, payment_method = $3, payment_proof = $4 WHERE source_payment_id = $5",
        [newAmount, newDate, newMethod, newProof, id]
      );

      // Logically update the master customer's phone number
      if (phone !== undefined) {
        await client.query(
          "UPDATE customers SET phone = $1 WHERE id = $2",
          [String(phone).trim(), p.customer_id]
        );
      }

      // Sync customer totals (due/status)
      await syncCustomerDue(client, p.customer_id);

    } else {
      // 2. If not found, try the sales table (for 'Due' ledger entries)
      const saleCheck = await client.query("SELECT * FROM sales WHERE id = $1 FOR UPDATE", [id]);
      if (saleCheck.rows.length > 0) {
        const s = saleCheck.rows[0];

        if (phone !== undefined) {
          await client.query(
            "UPDATE customers SET phone = $1 WHERE lower(trim(name)) = lower(trim($2))",
            [String(phone).trim(), s.customer]
          );
        }

        const updFields = [];
        const updVals = [];
        if (amount !== undefined) { updFields.push(`amount = $${updVals.length+1}`); updVals.push(Number(amount)); }
        if (date !== undefined) { updFields.push(`date = $${updVals.length+1}`); updVals.push(date); }
        if (payment_method !== undefined) { updFields.push(`payment_method = $${updVals.length+1}`); updVals.push(String(payment_method).trim()); }
        if (transaction_id !== undefined) { updFields.push(`transaction_id = $${updVals.length+1}`); updVals.push(String(transaction_id).trim()); }
        if (payment_proof !== undefined) { updFields.push(`payment_proof = $${updVals.length+1}`); updVals.push(String(payment_proof).trim()); }

        if (updFields.length > 0) {
           updVals.push(id);
           await client.query(`UPDATE sales SET ${updFields.join(", ")} WHERE id = $${updVals.length}`, updVals);
        }

        // Sync customer totals by name
        const custRes = await client.query("SELECT id FROM customers WHERE lower(trim(name)) = lower(trim($1))", [s.customer]);
        if (custRes.rows.length) {
          await syncCustomerDue(client, custRes.rows[0].id);
        }
      } else {
        throw new Error("Record not found in payments or sales.");
      }
    }

    await client.query("COMMIT");
    res.json({ success: true });
  } catch (e) {
    await client.query("ROLLBACK");
    console.error("[payments/patch]", e);
    res.status(400).json({ error: e.message });
  } finally {
    client.release();
  }
});

paymentsRouter.delete("/:id", async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const found = await client.query("SELECT * FROM customer_payments WHERE id=$1 FOR UPDATE", [req.params.id]);
    if (!found.rows.length) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Payment not found" });
    }
    const payment = found.rows[0];

    // Delete payment record
    await client.query("DELETE FROM customer_payments WHERE id=$1", [req.params.id]);

    // Delete linked whatsapp_bills audit record
    await client.query("DELETE FROM whatsapp_bills WHERE source_payment_id=$1", [req.params.id]);

    // Sync customer due & status
    await syncCustomerDue(client, payment.customer_id);

    await client.query("COMMIT");
    res.status(204).end();
  } catch (e) {
    await client.query("ROLLBACK");
    console.error(e);
    res.status(400).json({ error: "Failed to delete payment" });
  } finally {
    client.release();
  }
});
