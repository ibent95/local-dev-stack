import { drizzle } from "drizzle-orm/node-postgres";
import pg from "pg";
import * as schema from "./schema.js";

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL || "postgresql://app:app@localhost:5432/lds_wiki",
  max: 10,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 5_000,
});

export const db = drizzle(pool, { schema });

process.on("SIGTERM", async () => {
  await pool.end();
  process.exit(0);
});
