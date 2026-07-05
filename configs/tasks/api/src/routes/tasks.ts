import { Hono } from "hono";
import { db } from "../db/index.js";
import { tasks, taskLabels, taskComments, labels, statusColumns } from "../db/schema.js";
import { eq, and, asc, desc } from "drizzle-orm";

export const tasksRouter = new Hono();

// GET /api/projects/:projectId/tasks — list tasks for a project (grouped by status)
tasksRouter.get("/projects/:projectId/tasks", async (c) => {
  const projectId = Number(c.req.param("projectId"));
  const statusId = c.req.query("statusColumnId");

  const conditions = [eq(tasks.projectId, projectId)];
  if (statusId) conditions.push(eq(tasks.statusColumnId, Number(statusId)));

  const rows = await db
    .select()
    .from(tasks)
    .where(and(...conditions))
    .orderBy(asc(tasks.position), asc(tasks.createdAt));

  // Attach labels to each task
  const taskIds = rows.map((t) => t.id);
  const allLabels = taskIds.length > 0
    ? await db.select({ taskId: taskLabels.taskId, label: labels })
        .from(taskLabels)
        .innerJoin(labels, eq(taskLabels.labelId, labels.id))
    : [];

  const labelsByTask = new Map<number, typeof labels.$inferSelect[]>();
  for (const tl of allLabels) {
    const list = labelsByTask.get(tl.taskId) || [];
    list.push(tl.label);
    labelsByTask.set(tl.taskId, list);
  }

  const result = rows.map((t) => ({
    ...t,
    labels: labelsByTask.get(t.id) || [],
  }));

  return c.json(result);
});

// POST /api/projects/:projectId/tasks — create a task
tasksRouter.post("/projects/:projectId/tasks", async (c) => {
  const projectId = Number(c.req.param("projectId"));
  const body = await c.req.json<{
    title: string;
    description?: string;
    statusColumnId?: number;
    assignee?: string;
    priority?: string;
    position?: number;
    dueDate?: string;
    labelIds?: number[];
  }>();

  const [task] = await db.insert(tasks).values({
    projectId,
    title: body.title,
    description: body.description,
    statusColumnId: body.statusColumnId ?? null,
    assignee: body.assignee,
    priority: body.priority ?? "medium",
    position: body.position ?? 0,
    dueDate: body.dueDate ? new Date(body.dueDate) : null,
  }).returning();

  // Attach labels
  if (body.labelIds && body.labelIds.length > 0) {
    await db.insert(taskLabels).values(
      body.labelIds.map((labelId) => ({ taskId: task.id, labelId }))
    );
  }

  return c.json(task, 201);
});

// GET /api/tasks/:id — get single task with comments and labels
tasksRouter.get("/tasks/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const [task] = await db.select().from(tasks).where(eq(tasks.id, id));
  if (!task) return c.json({ error: "Task not found" }, 404);

  const taskLabelsList = await db
    .select({ label: labels })
    .from(taskLabels)
    .innerJoin(labels, eq(taskLabels.labelId, labels.id))
    .where(eq(taskLabels.taskId, id));

  const taskCommentsList = await db
    .select()
    .from(taskComments)
    .where(eq(taskComments.taskId, id))
    .orderBy(asc(taskComments.createdAt));

  return c.json({
    ...task,
    labels: taskLabelsList.map((tl) => tl.label),
    comments: taskCommentsList,
  });
});

// PATCH /api/tasks/:id — update a task (title, status, assignee, priority, etc.)
tasksRouter.patch("/tasks/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const body = await c.req.json<{
    title?: string;
    description?: string;
    statusColumnId?: number | null;
    assignee?: string;
    priority?: string;
    position?: number;
    dueDate?: string | null;
    labelIds?: number[];
  }>();

  const { labelIds, ...fields } = body;
  const updateData: Record<string, any> = { ...fields, updatedAt: new Date() };
  if (fields.dueDate !== undefined) {
    updateData.dueDate = fields.dueDate ? new Date(fields.dueDate) : null;
  }

  const [row] = await db.update(tasks).set(updateData).where(eq(tasks.id, id)).returning();
  if (!row) return c.json({ error: "Task not found" }, 404);

  // Update labels if provided
  if (labelIds !== undefined) {
    await db.delete(taskLabels).where(eq(taskLabels.taskId, id));
    if (labelIds.length > 0) {
      await db.insert(taskLabels).values(
        labelIds.map((labelId) => ({ taskId: id, labelId }))
      );
    }
  }

  return c.json(row);
});

// DELETE /api/tasks/:id
tasksRouter.delete("/tasks/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const deleted = await db.delete(tasks).where(eq(tasks.id, id)).returning();
  if (deleted.length === 0) return c.json({ error: "Task not found" }, 404);
  return c.json({ ok: true });
});

// ─── Task Comments ───────────────────────────────────────────────

// POST /api/tasks/:id/comments
tasksRouter.post("/tasks/:id/comments", async (c) => {
  const taskId = Number(c.req.param("id"));
  const body = await c.req.json<{ author?: string; content: string }>();

  const [row] = await db.insert(taskComments).values({
    taskId,
    author: body.author || "Anonymous",
    content: body.content,
  }).returning();

  return c.json(row, 201);
});

// DELETE /api/tasks/:taskId/comments/:commentId
tasksRouter.delete("/tasks/:taskId/comments/:commentId", async (c) => {
  const commentId = Number(c.req.param("commentId"));
  const deleted = await db.delete(taskComments).where(eq(taskComments.id, commentId)).returning();
  if (deleted.length === 0) return c.json({ error: "Comment not found" }, 404);
  return c.json({ ok: true });
});
