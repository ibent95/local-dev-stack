import { Hono } from "hono";
import { db } from "../db/index.js";
import { events, sites } from "../db/schema.js";
import { sql, eq, and, gte, lte, desc } from "drizzle-orm";

export const analyticsRouter = new Hono();

// Helper: parse date range from query params
function parseDateRange(c: any) {
  const since = c.req.query("since");
  const until = c.req.query("until");
  const defaultSince = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
  return {
    since: since ? new Date(since) : new Date(defaultSince),
    until: until ? new Date(until) : new Date(),
  };
}

// GET /api/analytics/:siteId/overview — high-level stats
analyticsRouter.get("/:siteId/overview", async (c) => {
  const siteId = c.req.param("siteId");
  const { since, until } = parseDateRange(c);

  const filter = and(
    eq(events.siteId, siteId),
    gte(events.createdAt, since),
    lte(events.createdAt, until),
  );

  const [totalPageviews] = await db
    .select({ count: sql<number>`count(*)::int` })
    .from(events)
    .where(filter);

  const [uniqueVisitors] = await db
    .select({ count: sql<number>`count(distinct ${events.createdAt}::date)::int` })
    .from(events)
    .where(filter);

  const [avgScreen] = await db
    .select({ avg: sql<number>`coalesce(avg(${events.screenWidth}), 0)::int` })
    .from(events)
    .where(filter);

  return c.json({
    totalPageviews: totalPageviews?.count || 0,
    uniqueVisitors: uniqueVisitors?.count || 0,
    avgScreenWidth: avgScreen?.avg || 0,
    period: { since: since.toISOString(), until: until.toISOString() },
  });
});

// GET /api/analytics/:siteId/pageviews — pageview count by day
analyticsRouter.get("/:siteId/pageviews", async (c) => {
  const siteId = c.req.param("siteId");
  const { since, until } = parseDateRange(c);

  const rows = await db
    .select({
      date: sql<string>`to_char(${events.createdAt}::date, 'YYYY-MM-DD')`,
      count: sql<number>`count(*)::int`,
    })
    .from(events)
    .where(and(eq(events.siteId, siteId), gte(events.createdAt, since), lte(events.createdAt, until)))
    .groupBy(sql`${events.createdAt}::date`)
    .orderBy(sql`${events.createdAt}::date`);

  return c.json(rows);
});

// GET /api/analytics/:siteId/top-pages — most visited pages
analyticsRouter.get("/:siteId/top-pages", async (c) => {
  const siteId = c.req.param("siteId");
  const { since, until } = parseDateRange(c);
  const limit = Number(c.req.query("limit")) || 10;

  const rows = await db
    .select({
      pathname: events.pathname,
      count: sql<number>`count(*)::int`,
    })
    .from(events)
    .where(and(eq(events.siteId, siteId), gte(events.createdAt, since), lte(events.createdAt, until)))
    .groupBy(events.pathname)
    .orderBy(desc(sql`count(*)`))
    .limit(limit);

  return c.json(rows);
});

// GET /api/analytics/:siteId/referrers — top referrers
analyticsRouter.get("/:siteId/referrers", async (c) => {
  const siteId = c.req.param("siteId");
  const { since, until } = parseDateRange(c);
  const limit = Number(c.req.query("limit")) || 10;

  const rows = await db
    .select({
      referrer: events.referrer,
      count: sql<number>`count(*)::int`,
    })
    .from(events)
    .where(and(
      eq(events.siteId, siteId),
      gte(events.createdAt, since),
      lte(events.createdAt, until),
      sql`${events.referrer} is not null and ${events.referrer} != ''`,
    ))
    .groupBy(events.referrer)
    .orderBy(desc(sql`count(*)`))
    .limit(limit);

  return c.json(rows);
});

// GET /api/analytics/:siteId/countries — visitors by country
analyticsRouter.get("/:siteId/countries", async (c) => {
  const siteId = c.req.param("siteId");
  const { since, until } = parseDateRange(c);
  const limit = Number(c.req.query("limit")) || 20;

  const rows = await db
    .select({
      country: events.country,
      count: sql<number>`count(*)::int`,
    })
    .from(events)
    .where(and(
      eq(events.siteId, siteId),
      gte(events.createdAt, since),
      lte(events.createdAt, until),
      sql`${events.country} is not null and ${events.country} != ''`,
    ))
    .groupBy(events.country)
    .orderBy(desc(sql`count(*)`))
    .limit(limit);

  return c.json(rows);
});

// GET /api/analytics/:siteId/devices — device breakdown
analyticsRouter.get("/:siteId/devices", async (c) => {
  const siteId = c.req.param("siteId");
  const { since, until } = parseDateRange(c);

  const rows = await db
    .select({
      device: events.device,
      count: sql<number>`count(*)::int`,
    })
    .from(events)
    .where(and(eq(events.siteId, siteId), gte(events.createdAt, since), lte(events.createdAt, until)))
    .groupBy(events.device)
    .orderBy(desc(sql`count(*)`));

  return c.json(rows);
});

// GET /api/analytics/:siteId/browsers — browser breakdown
analyticsRouter.get("/:siteId/browsers", async (c) => {
  const siteId = c.req.param("siteId");
  const { since, until } = parseDateRange(c);

  const rows = await db
    .select({
      browser: events.browser,
      count: sql<number>`count(*)::int`,
    })
    .from(events)
    .where(and(eq(events.siteId, siteId), gte(events.createdAt, since), lte(events.createdAt, until)))
    .groupBy(events.browser)
    .orderBy(desc(sql`count(*)`));

  return c.json(rows);
});

// GET /api/analytics/:siteId/recent — recent events (live feed)
analyticsRouter.get("/:siteId/recent", async (c) => {
  const siteId = c.req.param("siteId");
  const limit = Number(c.req.query("limit")) || 20;

  const rows = await db
    .select()
    .from(events)
    .where(eq(events.siteId, siteId))
    .orderBy(desc(events.createdAt))
    .limit(limit);

  return c.json(rows);
});
