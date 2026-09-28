import pg from "pg";
import dotenv from "dotenv";

dotenv.config({
  path: new URL("./.env", import.meta.url),
});

const { Pool, types } = pg;

// PostgreSQL DATE is a calendar date, not a timestamp. Keep it as a YYYY-MM-DD
// string so JSON serialization never shifts it to the previous day in IST.
types.setTypeParser(1082, (value) => value);

if (!process.env.DATABASE_URL) {
  console.warn(
    "[db] DATABASE_URL is not set. Check server/.env"
  );
}

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  connectionTimeoutMillis: 10000,
});

pool.on("error", (err) => {
  console.error("[db] Unexpected error on idle client", err);
});