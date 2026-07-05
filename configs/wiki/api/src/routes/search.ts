import { Hono } from "hono";
import { db } from "../db/index.js";
import { pages, spaces, categories } from "../db/schema.js";
import { eq, and, or, sql, ilike, desc } from "drizzle-orm";

export const searchRouter = new Hono();

// GET /api/search?q=query — full-text search across all pages
searchRouter.get("/", async (c) => {
  const query = c.req.query("q");
  if (!query || query.trim().length === 0) {
    return c.json([]);
  }

  const term = `%${query}%`;

  const rows = await db
    .select({
      id: pages.id,
      title: pages.title,
      slug: pages.slug,
      contentHtml: pages.contentHtml,
      viewCount: pages.viewCount,
      createdAt: pages.createdAt,
      updatedAt: pages.updatedAt,
      spaceName: spaces.name,
      spaceSlug: spaces.slug,
      categoryName: categories.name,
      // Simple relevance: title match > content match
      relevance: sql<number>`(
        CASE WHEN ${pages.title} ILIKE ${term} THEN 10 ELSE 0 END +
        CASE WHEN ${pages.contentHtml} ILIKE ${term} THEN 5 ELSE 0 END
      )`,
    })
    .from(pages)
    .leftJoin(spaces, eq(pages.spaceId, spaces.id))
    .leftJoin(categories, eq(pages.categoryId, categories.id))
    .where(
      and(
        eq(pages.isPublished, true),
        or(
          ilike(pages.title, term),
          ilike(pages.contentHtml, term),
        ),
      ),
    )
    .orderBy(desc(sql`relevance`), desc(pages.updatedAt))
    .limit(20);

  return c.json(rows);
});
