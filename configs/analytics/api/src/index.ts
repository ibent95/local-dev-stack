import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { serve } from "@hono/node-server";
import dotenv from "dotenv";
import { sitesRouter } from "./routes/sites.js";
import { trackRouter } from "./routes/track.js";
import { analyticsRouter } from "./routes/analytics.js";

dotenv.config();

const app = new Hono();

// ─── Middleware ────────────────────────────────────────────────────
app.use("*", logger());
app.use("*", cors({
  origin: process.env.CORS_ORIGIN || "*",
  allowMethods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowHeaders: ["Content-Type"],
}));

// ─── Health ───────────────────────────────────────────────────────
app.get("/api/health", (c) => c.json({ status: "ok", timestamp: Date.now() }));

// ─── Routes ───────────────────────────────────────────────────────
app.route("/api/sites", sitesRouter);
app.route("/api", trackRouter);
app.route("/api/analytics", analyticsRouter);

// ─── 404 ──────────────────────────────────────────────────────────
app.notFound((c) => c.json({ error: "Not Found" }, 404));

// ─── Start ────────────────────────────────────────────────────────
const port = Number(process.env.PORT) || 3001;

serve({ fetch: app.fetch, port }, () => {
  console.log(`📊 Analytics API running on http://localhost:${port}`);
});
