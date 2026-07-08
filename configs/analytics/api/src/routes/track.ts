import { Hono } from "hono";
import { eq } from "drizzle-orm";
import { db } from "../db/index.js";
import { events, sites } from "../db/schema.js";

export const trackRouter = new Hono();

// POST /api/track — ingest a single pageview event (public, no auth)
trackRouter.post("/track", async (c) => {
  const body = await c.req.json<{
    site_id?: string;
    domain?: string;
    pathname?: string;
    referrer?: string;
    country?: string;
    city?: string;
    device?: string;
    browser?: string;
    os?: string;
    screen_width?: number;
  }>();

  // Resolve site_id from domain if not provided
  let siteId = body.site_id;
  if (!siteId && body.domain) {
    const [site] = await db.select({ id: sites.id }).from(sites).where(eq(sites.domain, body.domain)).limit(1);
    if (site) siteId = site.id;
  }

  if (!siteId) {
    return c.json({ error: "Unknown site — provide site_id or a valid domain" }, 400);
  }

  // Insert event
  await db.insert(events).values({
    siteId,
    pathname: body.pathname || "/",
    referrer: body.referrer || null,
    country: body.country || null,
    city: body.city || null,
    device: body.device || null,
    browser: body.browser || null,
    os: body.os || null,
    screenWidth: body.screen_width || null,
  });

  return c.json({ ok: true });
});

// GET /api/track.js — tracking script (served as JavaScript for website embedding)
trackRouter.get("/track.js", (c) => {
  const script = `
(function() {
  var s = document.currentScript;
  var siteId = s ? s.getAttribute("data-site-id") : null;
  var endpoint = s ? s.src.replace(/\\/track\\.js$/, "/track") : "/api/track";

  function track() {
    var w = window;
    var d = document;
    var nav = navigator || {};

    fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        site_id: siteId,
        pathname: w.location.pathname,
        referrer: d.referrer || w.document.referrer,
        device: /Mobi|Android|iPhone/i.test(nav.userAgent) ? "mobile" : "desktop",
        browser: (function(ua) {
          if (ua.includes("Firefox")) return "firefox";
          if (ua.includes("Edg")) return "edge";
          if (ua.includes("Chrome")) return "chrome";
          if (ua.includes("Safari")) return "safari";
          return "other";
        })(nav.userAgent),
        os: (function(ua) {
          if (ua.includes("Win")) return "windows";
          if (ua.includes("Mac")) return "macos";
          if (ua.includes("Linux")) return "linux";
          if (ua.includes("Android")) return "android";
          if (ua.includes("iPhone") || ua.includes("iPad")) return "ios";
          return "other";
        })(nav.userAgent),
        screen_width: w.screen.width
      })
    }).catch(function(){});
  }

  if (d.readyState === "loading") {
    d.addEventListener("DOMContentLoaded", track);
  } else {
    track();
  }
})();
`;
  c.header("Content-Type", "application/javascript");
  c.header("Cache-Control", "public, max-age=3600");
  return c.body(script);
});
