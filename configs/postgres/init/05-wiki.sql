-- LDS Wiki standalone database initialization
-- Creates spaces, categories, pages, revisions, comments, and tags

CREATE TABLE IF NOT EXISTS spaces (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  slug VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  icon VARCHAR(10) DEFAULT '📚',
  color VARCHAR(7) DEFAULT '#6366f1',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS categories (
  id SERIAL PRIMARY KEY,
  space_id INTEGER REFERENCES spaces(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  slug VARCHAR(100) NOT NULL,
  description TEXT,
  position INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pages (
  id SERIAL PRIMARY KEY,
  space_id INTEGER REFERENCES spaces(id) ON DELETE CASCADE NOT NULL,
  category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  slug VARCHAR(200) NOT NULL,
  content JSONB,
  content_html TEXT,
  toc JSONB,
  version INTEGER NOT NULL DEFAULT 1,
  is_published BOOLEAN NOT NULL DEFAULT TRUE,
  is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
  view_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS page_revisions (
  id SERIAL PRIMARY KEY,
  page_id INTEGER REFERENCES pages(id) ON DELETE CASCADE NOT NULL,
  version INTEGER NOT NULL,
  title TEXT NOT NULL,
  content JSONB,
  content_html TEXT,
  message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS comments (
  id SERIAL PRIMARY KEY,
  page_id INTEGER REFERENCES pages(id) ON DELETE CASCADE NOT NULL,
  author TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tags (
  id SERIAL PRIMARY KEY,
  name VARCHAR(60) NOT NULL UNIQUE,
  color VARCHAR(7) DEFAULT '#6366f1'
);

CREATE TABLE IF NOT EXISTS page_tags (
  page_id INTEGER REFERENCES pages(id) ON DELETE CASCADE NOT NULL,
  tag_id INTEGER REFERENCES tags(id) ON DELETE CASCADE NOT NULL,
  PRIMARY KEY (page_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_pages_space ON pages(space_id);
CREATE INDEX IF NOT EXISTS idx_pages_category ON pages(category_id);
