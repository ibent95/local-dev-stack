import { Hono } from "hono";
import { db } from "../db/index.js";
import { sites } from "../db/schema.js";

export const sitesRouter = new Hono();

// GET /api/sites — list all sites
sitesRouter.get("/", async (c) => {
  const rows = await db.select().from(sites).orderBy(sites.createdAt);
  return c.json(rows);
});

// POST /api/sites — create a new site
sitesRouter.post("/", async (c) => {
  const body = await c.req.json<{ domain: string; name: string }>();
  const [row] = await db.insert(sites).values(body).returning();
  return c.json(row, 201);
});

// GET /api/sites/:id — get single site
sitesRouter.get("/:id", async (c) => {
  const id = c.req.param("id");
  const [row] = await db.select().from(sites).where(sites.id.eq(id));
  if (!row) return c.json({ error: "Site not found" }, 404);
  return c.json(row);
});

// DELETE /api/sites/:id — delete a site
sitesRouter.delete("/:id", async (c) => {
  const id = c.req.param("id");
  const deleted = await db.delete(sites).where(sites.id.eq(id)).returning();
  if (deleted.length === 0) return c.json({ error: "Site not found" }, 404);
  return c.json({ ok: true });
});
