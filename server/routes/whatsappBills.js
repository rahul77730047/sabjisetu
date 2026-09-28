import { pool } from "../db.js";
import { createCrudRouter } from "./crud.js";
import { toNum } from "./helpers.js";

export const whatsappBillsRouter = createCrudRouter({
  table: "whatsapp_bills",
  columns: ["customer", "phone", "amount", "date", "status", "kind", "message", "source_payment_id", "source_sale_id", "payment_method", "payment_proof"],
  orderBy: "date DESC, created_at DESC",
  mapOut: (row) => toNum(row, ["amount"]),
});

whatsappBillsRouter.post("/reminder-opened", async (req, res) => {
  const { customer, phone, amount } = req.body;
  try {
    const { rows } = await pool.query(
      `INSERT INTO whatsapp_bills (customer, phone, amount, date, status, kind)
       VALUES ($1, $2, $3, CURRENT_DATE, 'Sent Reminder', 'Reminder') RETURNING *`,
      [customer || 'Customer', phone || '', Number(amount || 0)]
    );
    res.json(toNum(rows[0], ["amount"]));
  } catch (err) {
    res.status(500).json({ error: "Failed to log WhatsApp reminder" });
  }
});
