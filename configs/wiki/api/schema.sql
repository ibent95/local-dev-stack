-- LDS Wiki API database schema
-- Run this after creating the lds_wiki database

-- Spaces — top-level document groupings
CREATE TABLE IF NOT EXISTS spaces (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  slug VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  icon VARCHAR(10) DEFAULT '📚',
  color VARCHAR(7) DEFAULT '#6366f1',
  created_at TIMESTAMP DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

-- Categories — mid-level grouping within a space
CREATE TABLE IF NOT EXISTS categories (
  id SERIAL PRIMARY KEY,
  space_id INTEGER NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug VARCHAR(100) NOT NULL,
  description TEXT,
  position INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

-- Pages — individual documentation pages
CREATE TABLE IF NOT EXISTS pages (
  id SERIAL PRIMARY KEY,
  space_id INTEGER NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  slug VARCHAR(200) NOT NULL,
  content JSONB,
  content_html TEXT,
  toc JSONB,
  version INTEGER NOT NULL DEFAULT 1,
  is_published BOOLEAN NOT NULL DEFAULT true,
  is_pinned BOOLEAN NOT NULL DEFAULT false,
  view_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

-- Indexes for pages
CREATE INDEX IF NOT EXISTS pages_space_idx ON pages(space_id);
CREATE INDEX IF NOT EXISTS pages_category_idx ON pages(category_id);

-- Page revisions — full version history
CREATE TABLE IF NOT EXISTS page_revisions (
  id SERIAL PRIMARY KEY,
  page_id INTEGER NOT NULL REFERENCES pages(id) ON DELETE CASCADE,
  version INTEGER NOT NULL,
  title TEXT NOT NULL,
  content JSONB,
  content_html TEXT,
  message TEXT,
  created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

-- Comments — discussion on pages
CREATE TABLE IF NOT EXISTS comments (
  id SERIAL PRIMARY KEY,
  page_id INTEGER NOT NULL REFERENCES pages(id) ON DELETE CASCADE,
  author TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

-- Tags — flexible tagging for pages
CREATE TABLE IF NOT EXISTS tags (
  id SERIAL PRIMARY KEY,
  name VARCHAR(60) NOT NULL UNIQUE,
  color VARCHAR(7) DEFAULT '#6366f1'
);

-- Page ↔ Tags (many-to-many)
CREATE TABLE IF NOT EXISTS page_tags (
  page_id INTEGER NOT NULL REFERENCES pages(id) ON DELETE CASCADE,
  tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE
);
