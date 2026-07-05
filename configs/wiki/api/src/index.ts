import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { serve } from "@hono/node-server";
import dotenv from "dotenv";
import { spacesRouter } from "./routes/spaces.js";
import { pagesRouter } from "./routes/pages.js";
import { searchRouter } from "./routes/search.js";

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
app.route("/api/spaces", spacesRouter);
app.route("/api/pages", pagesRouter);
app.route("/api/search", searchRouter);

// ─── 404 ──────────────────────────────────────────────────────────
app.notFound((c) => c.json({ error: "Not Found" }, 404));

// ─── Start ────────────────────────────────────────────────────────
const port = Number(process.env.PORT) || 3003;

serve({ fetch: app.fetch, port }, () => {
  console.log(`📖 LDS Wiki API running on http://localhost:${port}`);
});
