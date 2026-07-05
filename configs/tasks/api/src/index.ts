import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { serve } from "@hono/node-server";
import dotenv from "dotenv";
import { workspacesRouter } from "./routes/workspaces.js";
import { projectsRouter } from "./routes/projects.js";
import { tasksRouter } from "./routes/tasks.js";
import { wikiRouter } from "./routes/wiki.js";

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
app.route("/api/workspaces", workspacesRouter);
app.route("/api", projectsRouter);
app.route("/api", tasksRouter);
app.route("/api", wikiRouter);

// ─── 404 ──────────────────────────────────────────────────────────
app.notFound((c) => c.json({ error: "Not Found" }, 404));

// ─── Start ────────────────────────────────────────────────────────
const port = Number(process.env.PORT) || 3002;

serve({ fetch: app.fetch, port }, () => {
  console.log(`📋 LDS Tasks API running on http://localhost:${port}`);
});
