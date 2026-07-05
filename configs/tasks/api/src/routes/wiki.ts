import { Hono } from "hono";
import { db } from "../db/index.js";
import { wikiSpaces, wikiPages, wikiPageRevisions, wikiComments } from "../db/schema.js";
import { eq, and, asc, desc } from "drizzle-orm";

export const wikiRouter = new Hono();

// ─── Wiki Spaces ─────────────────────────────────────────────────

// GET /api/workspaces/:wsSlug/wiki — list wiki spaces for a workspace
wikiRouter.get("/workspaces/:wsSlug/wiki", async (c) => {
  const wsSlug = c.req.param("wsSlug");
  // Resolve workspace from slug to get its ID
  const [ws] = await db.select({ id: workspaces.id }).from(workspaces).where(eq(workspaces.slug, wsSlug));
  if (!ws) return c.json({ error: "Workspace not found" }, 404);
  const rows = await db
    .select()
    .from(wikiSpaces)
    .where(eq(wikiSpaces.workspaceId, ws.id))
    .orderBy(asc(wikiSpaces.createdAt));
  return c.json(rows);
});

// POST /api/wiki-spaces — create a wiki space
wikiRouter.post("/wiki-spaces", async (c) => {
  const body = await c.req.json<{
    workspaceId: number;
    name: string;
    slug?: string;
    description?: string;
  }>();

  const slug = body.slug || body.name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

  const [row] = await db.insert(wikiSpaces).values({
    workspaceId: body.workspaceId,
    name: body.name,
    slug,
    description: body.description,
  }).returning();

  return c.json(row, 201);
});

// GET /api/wiki-spaces/:slug — get wiki space with its pages
wikiRouter.get("/wiki-spaces/:slug", async (c) => {
  const slug = c.req.param("slug");
  const [space] = await db.select().from(wikiSpaces).where(eq(wikiSpaces.slug, slug));
  if (!space) return c.json({ error: "Wiki space not found" }, 404);

  const pagesList = await db
    .select()
    .from(wikiPages)
    .where(eq(wikiPages.spaceId, space.id))
    .orderBy(desc(wikiPages.updatedAt));

  return c.json({ ...space, pages: pagesList });
});

// ─── Wiki Pages ──────────────────────────────────────────────────

// POST /api/wiki-pages — create a wiki page
wikiRouter.post("/wiki-pages", async (c) => {
  const body = await c.req.json<{
    spaceId: number;
    title: string;
    slug?: string;
    content?: any;
    contentHtml?: string;
  }>();

  const slug = body.slug || body.title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

  const [page] = await db.insert(wikiPages).values({
    spaceId: body.spaceId,
    title: body.title,
    slug,
    content: body.content ?? null,
    contentHtml: body.contentHtml ?? null,
  }).returning();

  // Initial revision
  await db.insert(wikiPageRevisions).values({
    pageId: page.id,
    version: 1,
    content: page.content,
    contentHtml: page.contentHtml,
  });

  return c.json(page, 201);
});

// GET /api/wiki-pages/:slug — get single page
wikiRouter.get("/wiki-pages/:slug", async (c) => {
  const slug = c.req.param("slug");
  const [page] = await db.select().from(wikiPages).where(eq(wikiPages.slug, slug));
  if (!page) return c.json({ error: "Page not found" }, 404);

  const commentsList = await db
    .select()
    .from(wikiComments)
    .where(eq(wikiComments.pageId, page.id))
    .orderBy(asc(wikiComments.createdAt));

  return c.json({ ...page, comments: commentsList });
});

// PUT /api/wiki-pages/:slug — update a page (creates revision)
wikiRouter.put("/wiki-pages/:slug", async (c) => {
  const slug = c.req.param("slug");
  const [existing] = await db.select().from(wikiPages).where(eq(wikiPages.slug, slug));
  if (!existing) return c.json({ error: "Page not found" }, 404);

  const body = await c.req.json<{
    title?: string;
    content?: any;
    contentHtml?: string;
  }>();

  const newVersion = existing.version + 1;
  const [updated] = await db
    .update(wikiPages)
    .set({ ...body, version: newVersion, updatedAt: new Date() })
    .where(eq(wikiPages.id, existing.id))
    .returning();

  await db.insert(wikiPageRevisions).values({
    pageId: existing.id,
    version: newVersion,
    content: updated.content,
    contentHtml: updated.contentHtml,
  });

  return c.json(updated);
});

// GET /api/wiki-pages/:slug/revisions
wikiRouter.get("/wiki-pages/:slug/revisions", async (c) => {
  const slug = c.req.param("slug");
  const [page] = await db.select({ id: wikiPages.id }).from(wikiPages).where(eq(wikiPages.slug, slug));
  if (!page) return c.json({ error: "Page not found" }, 404);

  const rows = await db
    .select({ id: wikiPageRevisions.id, version: wikiPageRevisions.version, createdAt: wikiPageRevisions.createdAt })
    .from(wikiPageRevisions)
    .where(eq(wikiPageRevisions.pageId, page.id))
    .orderBy(desc(wikiPageRevisions.version));

  return c.json(rows);
});

// POST /api/wiki-pages/:slug/comments
wikiRouter.post("/wiki-pages/:slug/comments", async (c) => {
  const slug = c.req.param("slug");
  const [page] = await db.select({ id: wikiPages.id }).from(wikiPages).where(eq(wikiPages.slug, slug));
  if (!page) return c.json({ error: "Page not found" }, 404);

  const body = await c.req.json<{ author?: string; content: string }>();
  const [row] = await db.insert(wikiComments).values({
    pageId: page.id,
    author: body.author || "Anonymous",
    content: body.content,
  }).returning();

  return c.json(row, 201);
});
