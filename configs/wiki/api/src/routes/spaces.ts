import { Hono } from "hono";
import { db } from "../db/index.js";
import { spaces, categories, pages } from "../db/schema.js";
import { eq, asc, desc, sql } from "drizzle-orm";

export const spacesRouter = new Hono();

// ─── Spaces CRUD ─────────────────────────────────────────────────

// GET /api/spaces — list all spaces (with page counts)
spacesRouter.get("/", async (c) => {
  const rows = await db
    .select({
      id: spaces.id,
      name: spaces.name,
      slug: spaces.slug,
      description: spaces.description,
      icon: spaces.icon,
      color: spaces.color,
      createdAt: spaces.createdAt,
      updatedAt: spaces.updatedAt,
      pageCount: sql<number>`coalesce(count(${pages.id}), 0)::int`,
    })
    .from(spaces)
    .leftJoin(pages, eq(pages.spaceId, spaces.id))
    .groupBy(spaces.id)
    .orderBy(asc(spaces.createdAt));

  return c.json(rows);
});

// POST /api/spaces — create a new space
spacesRouter.post("/", async (c) => {
  const body = await c.req.json<{
    name: string;
    slug?: string;
    description?: string;
    icon?: string;
    color?: string;
  }>();

  const slug = body.slug || body.name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

  const [row] = await db.insert(spaces).values({
    name: body.name,
    slug,
    description: body.description,
    icon: body.icon,
    color: body.color,
  }).returning();

  return c.json(row, 201);
});

// GET /api/spaces/:slug — get single space with its categories
spacesRouter.get("/:slug", async (c) => {
  const slug = c.req.param("slug");
  const [space] = await db.select().from(spaces).where(eq(spaces.slug, slug));
  if (!space) return c.json({ error: "Space not found" }, 404);

  const cats = await db
    .select({
      id: categories.id,
      name: categories.name,
      slug: categories.slug,
      description: categories.description,
      position: categories.position,
      pageCount: sql<number>`coalesce(count(${pages.id}), 0)::int`,
    })
    .from(categories)
    .leftJoin(pages, eq(pages.categoryId, categories.id))
    .where(eq(categories.spaceId, space.id))
    .groupBy(categories.id)
    .orderBy(asc(categories.position));

  return c.json({ ...space, categories: cats });
});

// PATCH /api/spaces/:slug — update a space
spacesRouter.patch("/:slug", async (c) => {
  const slug = c.req.param("slug");
  const body = await c.req.json<{
    name?: string;
    description?: string;
    icon?: string;
    color?: string;
  }>();

  const [row] = await db
    .update(spaces)
    .set({ ...body, updatedAt: new Date() })
    .where(eq(spaces.slug, slug))
    .returning();

  if (!row) return c.json({ error: "Space not found" }, 404);
  return c.json(row);
});

// DELETE /api/spaces/:slug — delete a space (cascades categories + pages)
spacesRouter.delete("/:slug", async (c) => {
  const slug = c.req.param("slug");
  const deleted = await db.delete(spaces).where(eq(spaces.slug, slug)).returning();
  if (deleted.length === 0) return c.json({ error: "Space not found" }, 404);
  return c.json({ ok: true });
});

// ─── Categories (nested under spaces) ────────────────────────────

// POST /api/spaces/:slug/categories — create a category in a space
spacesRouter.post("/:slug/categories", async (c) => {
  const spaceSlug = c.req.param("slug");
  const [space] = await db.select({ id: spaces.id }).from(spaces).where(eq(spaces.slug, spaceSlug));
  if (!space) return c.json({ error: "Space not found" }, 404);

  const body = await c.req.json<{
    name: string;
    slug?: string;
    description?: string;
    position?: number;
  }>();

  const slug = body.slug || body.name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

  const [row] = await db.insert(categories).values({
    spaceId: space.id,
    name: body.name,
    slug,
    description: body.description,
    position: body.position ?? 0,
  }).returning();

  return c.json(row, 201);
});

// PATCH /api/spaces/:slug/categories/:catSlug — update category
spacesRouter.patch("/:slug/categories/:catSlug", async (c) => {
  const spaceSlug = c.req.param("slug");
  const catSlug = c.req.param("catSlug");
  const [space] = await db.select({ id: spaces.id }).from(spaces).where(eq(spaces.slug, spaceSlug));
  if (!space) return c.json({ error: "Space not found" }, 404);

  const body = await c.req.json<{ name?: string; description?: string; position?: number }>();

  const [row] = await db
    .update(categories)
    .set(body)
    .where(eq(categories.slug, catSlug))
    .returning();

  if (!row) return c.json({ error: "Category not found" }, 404);
  return c.json(row);
});

// DELETE /api/spaces/:slug/categories/:catSlug
spacesRouter.delete("/:slug/categories/:catSlug", async (c) => {
  const catSlug = c.req.param("catSlug");
  const deleted = await db.delete(categories).where(eq(categories.slug, catSlug)).returning();
  if (deleted.length === 0) return c.json({ error: "Category not found" }, 404);
  return c.json({ ok: true });
});
