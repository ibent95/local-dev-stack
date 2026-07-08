-- LDS Tasks API database schema
-- Run this after creating the lds_tasks database

-- Workspaces
CREATE TABLE IF NOT EXISTS workspaces (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  slug VARCHAR(100) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

-- Projects
CREATE TABLE IF NOT EXISTS projects (
  id SERIAL PRIMARY KEY,
  workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

-- Status columns (custom per-project status)
CREATE TABLE IF NOT EXISTS status_columns (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  color VARCHAR(7) DEFAULT '#6366f1'
);

-- Labels
CREATE TABLE IF NOT EXISTS labels (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color VARCHAR(7) DEFAULT '#6366f1'
);

-- Tasks
CREATE TABLE IF NOT EXISTS tasks (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  status_column_id INTEGER REFERENCES status_columns(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  assignee TEXT,
  priority VARCHAR(20) DEFAULT 'medium',
  position INTEGER NOT NULL DEFAULT 0,
  due_date TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

-- Task ↔ Label (many-to-many)
CREATE TABLE IF NOT EXISTS task_labels (
  task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  label_id INTEGER NOT NULL REFERENCES labels(id) ON DELETE CASCADE,
  PRIMARY KEY (task_id, label_id)
);

-- Task comments
CREATE TABLE IF NOT EXISTS task_comments (
  id SERIAL PRIMARY KEY,
  task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  author TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

-- Wiki spaces
CREATE TABLE IF NOT EXISTS wiki_spaces (
  id SERIAL PRIMARY KEY,
  workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug VARCHAR(100) NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

-- Wiki pages
CREATE TABLE IF NOT EXISTS wiki_pages (
  id SERIAL PRIMARY KEY,
  space_id INTEGER NOT NULL REFERENCES wiki_spaces(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  slug VARCHAR(200) NOT NULL,
  content JSONB,
  content_html TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

-- Wiki page revision history
CREATE TABLE IF NOT EXISTS wiki_page_revisions (
  id SERIAL PRIMARY KEY,
  page_id INTEGER NOT NULL REFERENCES wiki_pages(id) ON DELETE CASCADE,
  version INTEGER NOT NULL,
  content JSONB,
  content_html TEXT,
  created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

-- Wiki page comments
CREATE TABLE IF NOT EXISTS wiki_comments (
  id SERIAL PRIMARY KEY,
  page_id INTEGER NOT NULL REFERENCES wiki_pages(id) ON DELETE CASCADE,
  author TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW() NOT NULL
);
