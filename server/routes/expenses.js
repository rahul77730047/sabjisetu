import { createCrudRouter } from "./crud.js";
import { toNum } from "./helpers.js";

export const expensesRouter = createCrudRouter({
  table: "expenses",
  columns: ["date", "category", "note", "amount"],
  orderBy: "date DESC, created_at DESC",
  mapOut: (row) => toNum(row, ["amount"]),
});
