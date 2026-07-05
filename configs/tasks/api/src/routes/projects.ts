import { Hono } from "hono";
import { db } from "../db/index.js";
import { projects, statusColumns, labels } from "../db/schema.js";
import { eq, asc } from "drizzle-orm";

export const projectsRouter = new Hono();

// GET /api/projects/:id — get project with status columns and labels
projectsRouter.get("/projects/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const [proj] = await db.select().from(projects).where(eq(projects.id, id));
  if (!proj) return c.json({ error: "Project not found" }, 404);

  const cols = await db.select().from(statusColumns)
    .where(eq(statusColumns.projectId, id))
    .orderBy(asc(statusColumns.position));

  const lbls = await db.select().from(labels)
    .where(eq(labels.projectId, id));

  return c.json({ ...proj, statusColumns: cols, labels: lbls });
});

// POST /api/projects/:id/status-columns
projectsRouter.post("/projects/:id/status-columns", async (c) => {
  const projectId = Number(c.req.param("id"));
  const body = await c.req.json<{ name: string; color?: string; position?: number }>();

  const [col] = await db.insert(statusColumns).values({
    projectId,
    name: body.name,
    color: body.color,
    position: body.position ?? 0,
  }).returning();

  return c.json(col, 201);
});

// PATCH /api/projects/:id/status-columns/:colId
projectsRouter.patch("/projects/:id/status-columns/:colId", async (c) => {
  const colId = Number(c.req.param("colId"));
  const body = await c.req.json<{ name?: string; color?: string; position?: number }>();
  const [row] = await db.update(statusColumns).set(body).where(eq(statusColumns.id, colId)).returning();
  if (!row) return c.json({ error: "Column not found" }, 404);
  return c.json(row);
});

// DELETE /api/projects/:id/status-columns/:colId
projectsRouter.delete("/projects/:id/status-columns/:colId", async (c) => {
  const colId = Number(c.req.param("colId"));
  const deleted = await db.delete(statusColumns).where(eq(statusColumns.id, colId)).returning();
  if (deleted.length === 0) return c.json({ error: "Column not found" }, 404);
  return c.json({ ok: true });
});

// POST /api/projects/:id/labels
projectsRouter.post("/projects/:id/labels", async (c) => {
  const projectId = Number(c.req.param("id"));
  const body = await c.req.json<{ name: string; color?: string }>();

  const [label] = await db.insert(labels).values({
    projectId,
    name: body.name,
    color: body.color,
  }).returning();

  return c.json(label, 201);
});

// DELETE /api/projects/:id/labels/:labelId
projectsRouter.delete("/projects/:id/labels/:labelId", async (c) => {
  const labelId = Number(c.req.param("labelId"));
  const deleted = await db.delete(labels).where(eq(labels.id, labelId)).returning();
  if (deleted.length === 0) return c.json({ error: "Label not found" }, 404);
  return c.json({ ok: true });
});
