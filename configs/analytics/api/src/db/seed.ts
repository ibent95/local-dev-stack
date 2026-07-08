import { eq } from "drizzle-orm";
import { db } from "./index.js";
import { sites } from "./schema.js";

async function ensureSite(domain: string, name: string): Promise<string> {
  const existing = await db.select().from(sites).where(eq(sites.domain, domain)).limit(1);
  if (existing.length > 0) return existing[0].id;

  const [row] = await db.insert(sites).values({ domain, name }).returning({ id: sites.id });
  return row.id;
}

async function seed() {
  console.log("🌱 Seeding default site...");
  const id = await ensureSite("localhost", "Local Dev Site");
  console.log(`  ✓ Site ready: ${id}`);
}

seed()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Seed failed:", err);
    process.exit(1);
  });
