import { Hono } from "hono";
import { db } from "../db/index.js";
import { workspaces, projects, tasks, statusColumns } from "../db/schema.js";
import { eq, asc, sql } from "drizzle-orm";

export const workspacesRouter = new Hono();

// GET /api/workspaces — list all workspaces with project counts
workspacesRouter.get("/", async (c) => {
  const rows = await db
    .select({
      id: workspaces.id,
      name: workspaces.name,
      slug: workspaces.slug,
      createdAt: workspaces.createdAt,
      projectCount: sql<number>`coalesce(count(${projects.id}), 0)::int`,
    })
    .from(workspaces)
    .leftJoin(projects, eq(projects.workspaceId, workspaces.id))
    .groupBy(workspaces.id)
    .orderBy(asc(workspaces.createdAt));

  return c.json(rows);
});

// POST /api/workspaces — create a new workspace
workspacesRouter.post("/", async (c) => {
  const body = await c.req.json<{ name: string; slug?: string }>();
  const slug = body.slug || body.name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

  const [row] = await db.insert(workspaces).values({ name: body.name, slug }).returning();
  return c.json(row, 201);
});

// GET /api/workspaces/:slug — get workspace with its projects
workspacesRouter.get("/:slug", async (c) => {
  const slug = c.req.param("slug");
  const [ws] = await db.select().from(workspaces).where(eq(workspaces.slug, slug));
  if (!ws) return c.json({ error: "Workspace not found" }, 404);

  const projs = await db
    .select({
      id: projects.id,
      name: projects.name,
      description: projects.description,
      createdAt: projects.createdAt,
      taskCount: sql<number>`coalesce(count(${tasks.id}), 0)::int`,
    })
    .from(projects)
    .leftJoin(tasks, eq(tasks.projectId, projects.id))
    .where(eq(projects.workspaceId, ws.id))
    .groupBy(projects.id)
    .orderBy(asc(projects.createdAt));

  return c.json({ ...ws, projects: projs });
});

// PATCH /api/workspaces/:slug
workspacesRouter.patch("/:slug", async (c) => {
  const slug = c.req.param("slug");
  const body = await c.req.json<{ name?: string }>();
  const [row] = await db.update(workspaces).set(body).where(eq(workspaces.slug, slug)).returning();
  if (!row) return c.json({ error: "Workspace not found" }, 404);
  return c.json(row);
});

// DELETE /api/workspaces/:slug
workspacesRouter.delete("/:slug", async (c) => {
  const slug = c.req.param("slug");
  const deleted = await db.delete(workspaces).where(eq(workspaces.slug, slug)).returning();
  if (deleted.length === 0) return c.json({ error: "Workspace not found" }, 404);
  return c.json({ ok: true });
});

// ─── Projects (nested under workspaces) ──────────────────────────

// POST /api/workspaces/:slug/projects
workspacesRouter.post("/:slug/projects", async (c) => {
  const wsSlug = c.req.param("slug");
  const [ws] = await db.select({ id: workspaces.id }).from(workspaces).where(eq(workspaces.slug, wsSlug));
  if (!ws) return c.json({ error: "Workspace not found" }, 404);

  const body = await c.req.json<{ name: string; description?: string }>();
  const [proj] = await db.insert(projects).values({
    workspaceId: ws.id,
    name: body.name,
    description: body.description,
  }).returning();

  // Create default status columns for the project
  const defaults = ["Backlog", "To Do", "In Progress", "Done"];
  for (let i = 0; i < defaults.length; i++) {
    await db.insert(statusColumns).values({
      projectId: proj.id,
      name: defaults[i],
      position: i,
      color: i === defaults.length - 1 ? "#22c55e" : "#6366f1",
    });
  }

  return c.json(proj, 201);
});

// PATCH /api/workspaces/:slug/projects/:projectSlug
workspacesRouter.patch("/:slug/projects/:projectSlug", async (c) => {
  const projectSlug = c.req.param("projectSlug");
  const body = await c.req.json<{ name?: string; description?: string }>();
  const [row] = await db.update(projects).set(body).where(eq(projects.name, projectSlug)).returning();
  if (!row) return c.json({ error: "Project not found" }, 404);
  return c.json(row);
});

// DELETE /api/workspaces/:slug/projects/:projectSlug
workspacesRouter.delete("/:slug/projects/:projectSlug", async (c) => {
  const projectSlug = c.req.param("projectSlug");
  const deleted = await db.delete(projects).where(eq(projects.name, projectSlug)).returning();
  if (deleted.length === 0) return c.json({ error: "Project not found" }, 404);
  return c.json({ ok: true });
});
