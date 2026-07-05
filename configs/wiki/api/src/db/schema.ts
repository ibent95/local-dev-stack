import {
  pgTable, serial, text, timestamp, integer, jsonb, varchar, boolean, index,
} from "drizzle-orm/pg-core";

// ─── Spaces — top-level document groupings ───────────────────────
export const spaces = pgTable("spaces", {
  id: serial("id").primaryKey(),
  name: text("name").notNull(),
  slug: varchar("slug", { length: 100 }).notNull().unique(),
  description: text("description"),
  icon: varchar("icon", { length: 10 }).default("📚"),
  color: varchar("color", { length: 7 }).default("#6366f1"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

// ─── Categories — mid-level grouping within a space ──────────────
export const categories = pgTable("categories", {
  id: serial("id").primaryKey(),
  spaceId: integer("space_id")
    .references(() => spaces.id, { onDelete: "cascade" })
    .notNull(),
  name: text("name").notNull(),
  slug: varchar("slug", { length: 100 }).notNull(),
  description: text("description"),
  position: integer("position").notNull().default(0),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// ─── Pages — individual documentation pages ──────────────────────
export const pages = pgTable("pages", {
  id: serial("id").primaryKey(),
  spaceId: integer("space_id")
    .references(() => spaces.id, { onDelete: "cascade" })
    .notNull(),
  categoryId: integer("category_id")
    .references(() => categories.id, { onDelete: "set null" }),
  title: text("title").notNull(),
  slug: varchar("slug", { length: 200 }).notNull(),
  // TipTap/ProseMirror JSON for the rich text editor
  content: jsonb("content"),
  // Rendered HTML for quick reads / search indexing
  contentHtml: text("content_html"),
  // Table of contents auto-generated from headings
  toc: jsonb("toc"),
  version: integer("version").notNull().default(1),
  isPublished: boolean("is_published").notNull().default(true),
  isPinned: boolean("is_pinned").notNull().default(false),
  viewCount: integer("view_count").notNull().default(0),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
}, (table) => ({
  spaceIdIdx: index("pages_space_idx").on(table.spaceId),
  categoryIdIdx: index("pages_category_idx").on(table.categoryId),
}));

// ─── Page revisions — full version history ───────────────────────
export const pageRevisions = pgTable("page_revisions", {
  id: serial("id").primaryKey(),
  pageId: integer("page_id")
    .references(() => pages.id, { onDelete: "cascade" })
    .notNull(),
  version: integer("version").notNull(),
  title: text("title").notNull(),
  content: jsonb("content"),
  contentHtml: text("content_html"),
  message: text("message"),           // edit summary
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// ─── Comments — discussion on pages ──────────────────────────────
export const comments = pgTable("comments", {
  id: serial("id").primaryKey(),
  pageId: integer("page_id")
    .references(() => pages.id, { onDelete: "cascade" })
    .notNull(),
  author: text("author"),
  content: text("content").notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// ─── Tags — flexible tagging for pages ───────────────────────────
export const tags = pgTable("tags", {
  id: serial("id").primaryKey(),
  name: varchar("name", { length: 60 }).notNull().unique(),
  color: varchar("color", { length: 7 }).default("#6366f1"),
});

export const pageTags = pgTable("page_tags", {
  pageId: integer("page_id")
    .references(() => pages.id, { onDelete: "cascade" })
    .notNull(),
  tagId: integer("tag_id")
    .references(() => tags.id, { onDelete: "cascade" })
    .notNull(),
});

// ─── Types ───────────────────────────────────────────────────────
export type Space = typeof spaces.$inferSelect;
export type NewSpace = typeof spaces.$inferInsert;
export type Category = typeof categories.$inferSelect;
export type NewCategory = typeof categories.$inferInsert;
export type Page = typeof pages.$inferSelect;
export type NewPage = typeof pages.$inferInsert;
export type PageRevision = typeof pageRevisions.$inferSelect;
export type Comment = typeof comments.$inferSelect;
export type Tag = typeof tags.$inferSelect;
export type NewTag = typeof tags.$inferInsert;
