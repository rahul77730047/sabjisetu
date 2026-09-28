import { createCrudRouter } from "./crud.js";
import { toNum } from "./helpers.js";

export const labourRouter = createCrudRouter({
  table: "labour",
  columns: ["date", "name", "work_type", "workers", "amount"],
  orderBy: "date DESC, created_at DESC",
  mapOut: (row) => toNum(row, ["workers", "amount"]),
});
