import {
  pgTable, serial, uuid, text, timestamp, integer, jsonb, boolean, varchar,
} from "drizzle-orm/pg-core";

// ─── Workspaces ──────────────────────────────────────────────────
export const workspaces = pgTable("workspaces", {
  id: serial("id").primaryKey(),
  name: text("name").notNull(),
  slug: varchar("slug", { length: 100 }).notNull().unique(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// ─── Projects ────────────────────────────────────────────────────
export const projects = pgTable("projects", {
  id: serial("id").primaryKey(),
  workspaceId: integer("workspace_id")
    .references(() => workspaces.id, { onDelete: "cascade" })
    .notNull(),
  name: text("name").notNull(),
  description: text("description"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// ─── Status columns (custom per-project status) ──────────────────
export const statusColumns = pgTable("status_columns", {
  id: serial("id").primaryKey(),
  projectId: integer("project_id")
    .references(() => projects.id, { onDelete: "cascade" })
    .notNull(),
  name: text("name").notNull(),
  position: integer("position").notNull().default(0),
  color: varchar("color", { length: 7 }).default("#6366f1"),
});

// ─── Labels ──────────────────────────────────────────────────────
export const labels = pgTable("labels", {
  id: serial("id").primaryKey(),
  projectId: integer("project_id")
    .references(() => projects.id, { onDelete: "cascade" })
    .notNull(),
  name: text("name").notNull(),
  color: varchar("color", { length: 7 }).default("#6366f1"),
});

// ─── Tasks ───────────────────────────────────────────────────────
export const tasks = pgTable("tasks", {
  id: serial("id").primaryKey(),
  projectId: integer("project_id")
    .references(() => projects.id, { onDelete: "cascade" })
    .notNull(),
  statusColumnId: integer("status_column_id")
    .references(() => statusColumns.id, { onDelete: "set null" }),
  title: text("title").notNull(),
  description: text("description"),
  assignee: text("assignee"),
  priority: varchar("priority", { length: 20 }).default("medium"), // low | medium | high | urgent
  position: integer("position").notNull().default(0),
  dueDate: timestamp("due_date"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

// ─── Task ↔ Label (many-to-many) ────────────────────────────────
export const taskLabels = pgTable("task_labels", {
  taskId: integer("task_id")
    .references(() => tasks.id, { onDelete: "cascade" })
    .notNull(),
  labelId: integer("label_id")
    .references(() => labels.id, { onDelete: "cascade" })
    .notNull(),
});

// ─── Task comments ───────────────────────────────────────────────
export const taskComments = pgTable("task_comments", {
  id: serial("id").primaryKey(),
  taskId: integer("task_id")
    .references(() => tasks.id, { onDelete: "cascade" })
    .notNull(),
  author: text("author"),
  content: text("content").notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// ─── Wiki spaces ─────────────────────────────────────────────────
export const wikiSpaces = pgTable("wiki_spaces", {
  id: serial("id").primaryKey(),
  workspaceId: integer("workspace_id")
    .references(() => workspaces.id, { onDelete: "cascade" })
    .notNull(),
  name: text("name").notNull(),
  slug: varchar("slug", { length: 100 }).notNull(),
  description: text("description"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// ─── Wiki pages ──────────────────────────────────────────────────
export const wikiPages = pgTable("wiki_pages", {
  id: serial("id").primaryKey(),
  spaceId: integer("space_id")
    .references(() => wikiSpaces.id, { onDelete: "cascade" })
    .notNull(),
  title: text("title").notNull(),
  slug: varchar("slug", { length: 200 }).notNull(),
  content: jsonb("content"),           // TipTap/ProseMirror JSON
  contentHtml: text("content_html"),   // rendered HTML for quick reads
  version: integer("version").notNull().default(1),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

// ─── Wiki page revision history ──────────────────────────────────
export const wikiPageRevisions = pgTable("wiki_page_revisions", {
  id: serial("id").primaryKey(),
  pageId: integer("page_id")
    .references(() => wikiPages.id, { onDelete: "cascade" })
    .notNull(),
  version: integer("version").notNull(),
  content: jsonb("content"),
  contentHtml: text("content_html"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// ─── Wiki page comments ──────────────────────────────────────────
export const wikiComments = pgTable("wiki_comments", {
  id: serial("id").primaryKey(),
  pageId: integer("page_id")
    .references(() => wikiPages.id, { onDelete: "cascade" })
    .notNull(),
  author: text("author"),
  content: text("content").notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// ─── Types ───────────────────────────────────────────────────────
export type Workspace = typeof workspaces.$inferSelect;
export type NewWorkspace = typeof workspaces.$inferInsert;
export type Project = typeof projects.$inferSelect;
export type NewProject = typeof projects.$inferInsert;
export type StatusColumn = typeof statusColumns.$inferSelect;
export type NewStatusColumn = typeof statusColumns.$inferInsert;
export type Label = typeof labels.$inferSelect;
export type NewLabel = typeof labels.$inferInsert;
export type Task = typeof tasks.$inferSelect;
export type NewTask = typeof tasks.$inferInsert;
export type TaskComment = typeof taskComments.$inferSelect;
export type WikiSpace = typeof wikiSpaces.$inferSelect;
export type NewWikiSpace = typeof wikiSpaces.$inferInsert;
export type WikiPage = typeof wikiPages.$inferSelect;
export type NewWikiPage = typeof wikiPages.$inferInsert;
export type WikiPageRevision = typeof wikiPageRevisions.$inferSelect;
export type WikiComment = typeof wikiComments.$inferSelect;
