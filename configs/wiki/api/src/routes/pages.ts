import { Hono } from "hono";
import { db } from "../db/index.js";
import { pages, pageRevisions, comments, spaces, categories, pageTags, tags } from "../db/schema.js";
import { eq, and, desc, asc, sql } from "drizzle-orm";

export const pagesRouter = new Hono();

// ─── Pages CRUD ──────────────────────────────────────────────────

// GET /api/pages — list all pages (with space/category info)
pagesRouter.get("/", async (c) => {
  const spaceSlug = c.req.query("space");
  const catSlug = c.req.query("category");

  const conditions = [eq(pages.isPublished, true)];

  if (spaceSlug) {
    const [space] = await db.select({ id: spaces.id }).from(spaces).where(eq(spaces.slug, spaceSlug));
    if (space) conditions.push(eq(pages.spaceId, space.id));
  }

  if (catSlug) {
    const [cat] = await db.select({ id: categories.id }).from(categories).where(eq(categories.slug, catSlug));
    if (cat) conditions.push(eq(pages.categoryId, cat.id));
  }

  const rows = await db
    .select({
      id: pages.id,
      title: pages.title,
      slug: pages.slug,
      version: pages.version,
      isPinned: pages.isPinned,
      viewCount: pages.viewCount,
      createdAt: pages.createdAt,
      updatedAt: pages.updatedAt,
      spaceName: spaces.name,
      spaceSlug: spaces.slug,
      categoryName: categories.name,
    })
    .from(pages)
    .leftJoin(spaces, eq(pages.spaceId, spaces.id))
    .leftJoin(categories, eq(pages.categoryId, categories.id))
    .where(and(...conditions))
    .orderBy(desc(pages.isPinned), desc(pages.updatedAt));

  return c.json(rows);
});

// GET /api/pages/:slug — get single page with full content
pagesRouter.get("/:slug", async (c) => {
  const slug = c.req.param("slug");
  const [page] = await db.select().from(pages).where(eq(pages.slug, slug));
  if (!page) return c.json({ error: "Page not found" }, 404);

  // Increment view count
  await db.update(pages).set({ viewCount: page.viewCount + 1 }).where(eq(pages.id, page.id));

  // Fetch associated tags
  const pageTagsList = await db
    .select({ id: tags.id, name: tags.name, color: tags.color })
    .from(pageTags)
    .innerJoin(tags, eq(pageTags.tagId, tags.id))
    .where(eq(pageTags.pageId, page.id));

  // Fetch recent comments
  const pageComments = await db
    .select()
    .from(comments)
    .where(eq(comments.pageId, page.id))
    .orderBy(asc(comments.createdAt));

  // Fetch space and category info
  const [space] = await db.select().from(spaces).where(eq(spaces.id, page.spaceId));
  const category = page.categoryId
    ? (await db.select().from(categories).where(eq(categories.id, page.categoryId)))[0]
    : null;

  return c.json({ ...page, tags: pageTagsList, comments: pageComments, space, category });
});

// POST /api/pages — create a new page
pagesRouter.post("/", async (c) => {
  const body = await c.req.json<{
    spaceId: number;
    categoryId?: number | null;
    title: string;
    slug?: string;
    content?: any;
    contentHtml?: string;
    toc?: any;
    isPublished?: boolean;
    isPinned?: boolean;
    tagIds?: number[];
  }>();

  const slug = body.slug || body.title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

  const [page] = await db.insert(pages).values({
    spaceId: body.spaceId,
    categoryId: body.categoryId ?? null,
    title: body.title,
    slug,
    content: body.content ?? null,
    contentHtml: body.contentHtml ?? null,
    toc: body.toc ?? null,
    isPublished: body.isPublished ?? true,
    isPinned: body.isPinned ?? false,
  }).returning();

  // Attach tags
  if (body.tagIds && body.tagIds.length > 0) {
    await db.insert(pageTags).values(
      body.tagIds.map((tagId) => ({ pageId: page.id, tagId }))
    );
  }

  // Create initial revision
  await db.insert(pageRevisions).values({
    pageId: page.id,
    version: 1,
    title: page.title,
    content: page.content,
    contentHtml: page.contentHtml,
    message: "Initial creation",
  });

  return c.json(page, 201);
});

// PUT /api/pages/:slug — update a page (creates revision)
pagesRouter.put("/:slug", async (c) => {
  const slug = c.req.param("slug");
  const [existing] = await db.select().from(pages).where(eq(pages.slug, slug));
  if (!existing) return c.json({ error: "Page not found" }, 404);

  const body = await c.req.json<{
    title?: string;
    content?: any;
    contentHtml?: string;
    toc?: any;
    categoryId?: number | null;
    isPublished?: boolean;
    isPinned?: boolean;
    message?: string;
    tagIds?: number[];
  }>();

  const newVersion = existing.version + 1;

  const [updated] = await db
    .update(pages)
    .set({
      ...(body.title !== undefined && { title: body.title }),
      ...(body.content !== undefined && { content: body.content }),
      ...(body.contentHtml !== undefined && { contentHtml: body.contentHtml }),
      ...(body.toc !== undefined && { toc: body.toc }),
      ...(body.categoryId !== undefined && { categoryId: body.categoryId }),
      ...(body.isPublished !== undefined && { isPublished: body.isPublished }),
      ...(body.isPinned !== undefined && { isPinned: body.isPinned }),
      version: newVersion,
      updatedAt: new Date(),
    })
    .where(eq(pages.id, existing.id))
    .returning();

  // Save revision
  await db.insert(pageRevisions).values({
    pageId: existing.id,
    version: newVersion,
    title: updated.title,
    content: updated.content,
    contentHtml: updated.contentHtml,
    message: body.message || null,
  });

  // Update tags if provided
  if (body.tagIds !== undefined) {
    await db.delete(pageTags).where(eq(pageTags.pageId, existing.id));
    if (body.tagIds.length > 0) {
      await db.insert(pageTags).values(
        body.tagIds.map((tagId) => ({ pageId: existing.id, tagId }))
      );
    }
  }

  return c.json(updated);
});

// DELETE /api/pages/:slug — delete a page
pagesRouter.delete("/:slug", async (c) => {
  const slug = c.req.param("slug");
  const deleted = await db.delete(pages).where(eq(pages.slug, slug)).returning();
  if (deleted.length === 0) return c.json({ error: "Page not found" }, 404);
  return c.json({ ok: true });
});

// ─── Revisions ───────────────────────────────────────────────────

// GET /api/pages/:slug/revisions — list revision history
pagesRouter.get("/:slug/revisions", async (c) => {
  const slug = c.req.param("slug");
  const [page] = await db.select({ id: pages.id }).from(pages).where(eq(pages.slug, slug));
  if (!page) return c.json({ error: "Page not found" }, 404);

  const rows = await db
    .select({
      id: pageRevisions.id,
      version: pageRevisions.version,
      title: pageRevisions.title,
      message: pageRevisions.message,
      createdAt: pageRevisions.createdAt,
    })
    .from(pageRevisions)
    .where(eq(pageRevisions.pageId, page.id))
    .orderBy(desc(pageRevisions.version));

  return c.json(rows);
});

// GET /api/pages/:slug/revisions/:version — get a specific revision
pagesRouter.get("/:slug/revisions/:version", async (c) => {
  const slug = c.req.param("slug");
  const version = Number(c.req.param("version"));
  const [page] = await db.select({ id: pages.id }).from(pages).where(eq(pages.slug, slug));
  if (!page) return c.json({ error: "Page not found" }, 404);

  const [rev] = await db
    .select()
    .from(pageRevisions)
    .where(and(eq(pageRevisions.pageId, page.id), eq(pageRevisions.version, version)));
  if (!rev) return c.json({ error: "Revision not found" }, 404);

  return c.json(rev);
});

// ─── Comments ────────────────────────────────────────────────────

// GET /api/pages/:slug/comments — list comments
pagesRouter.get("/:slug/comments", async (c) => {
  const slug = c.req.param("slug");
  const [page] = await db.select({ id: pages.id }).from(pages).where(eq(pages.slug, slug));
  if (!page) return c.json({ error: "Page not found" }, 404);

  const rows = await db
    .select()
    .from(comments)
    .where(eq(comments.pageId, page.id))
    .orderBy(asc(comments.createdAt));

  return c.json(rows);
});

// POST /api/pages/:slug/comments — add a comment
pagesRouter.post("/:slug/comments", async (c) => {
  const slug = c.req.param("slug");
  const [page] = await db.select({ id: pages.id }).from(pages).where(eq(pages.slug, slug));
  if (!page) return c.json({ error: "Page not found" }, 404);

  const body = await c.req.json<{ author?: string; content: string }>();
  const [row] = await db.insert(comments).values({
    pageId: page.id,
    author: body.author || "Anonymous",
    content: body.content,
  }).returning();

  return c.json(row, 201);
});
