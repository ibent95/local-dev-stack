import { pgTable, uuid, text, timestamp, integer, jsonb } from "drizzle-orm/pg-core";

// ─── Sites ────────────────────────────────────────────────────────
export const sites = pgTable("sites", {
  id: uuid("id").primaryKey().defaultRandom(),
  domain: text("domain").notNull().unique(),
  name: text("name").notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// ─── Events ───────────────────────────────────────────────────────
export const events = pgTable("events", {
  id: integer("id").primaryKey().generatedAlwaysAsIdentity(),
  siteId: uuid("site_id")
    .references(() => sites.id, { onDelete: "cascade" })
    .notNull(),
  pathname: text("pathname").notNull().default("/"),
  referrer: text("referrer"),
  country: text("country"),
  city: text("city"),
  device: text("device"),       // desktop | mobile | tablet
  browser: text("browser"),    // chrome | firefox | safari | edge | other
  os: text("os"),              // windows | macos | linux | android | ios | other
  screenWidth: integer("screen_width"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export type Site = typeof sites.$inferSelect;
export type NewSite = typeof sites.$inferInsert;
export type Event = typeof events.$inferSelect;
export type NewEvent = typeof events.$inferInsert;
