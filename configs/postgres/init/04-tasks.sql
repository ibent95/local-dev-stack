-- LDS Tasks database initialization
-- Creates workspaces, projects, tasks, and wiki tables

CREATE TABLE IF NOT EXISTS workspaces (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  slug VARCHAR(100) NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS projects (
  id SERIAL PRIMARY KEY,
  workspace_id INTEGER REFERENCES workspaces(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS status_columns (
  id SERIAL PRIMARY KEY,
  project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  color VARCHAR(7) DEFAULT '#6366f1'
);

CREATE TABLE IF NOT EXISTS labels (
  id SERIAL PRIMARY KEY,
  project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  color VARCHAR(7) DEFAULT '#6366f1'
);

CREATE TABLE IF NOT EXISTS tasks (
  id SERIAL PRIMARY KEY,
  project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
  status_column_id INTEGER REFERENCES status_columns(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  assignee TEXT,
  priority VARCHAR(20) DEFAULT 'medium',
  position INTEGER NOT NULL DEFAULT 0,
  due_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS task_labels (
  task_id INTEGER REFERENCES tasks(id) ON DELETE CASCADE NOT NULL,
  label_id INTEGER REFERENCES labels(id) ON DELETE CASCADE NOT NULL,
  PRIMARY KEY (task_id, label_id)
);

CREATE TABLE IF NOT EXISTS task_comments (
  id SERIAL PRIMARY KEY,
  task_id INTEGER REFERENCES tasks(id) ON DELETE CASCADE NOT NULL,
  author TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wiki_spaces (
  id SERIAL PRIMARY KEY,
  workspace_id INTEGER REFERENCES workspaces(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  slug VARCHAR(100) NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wiki_pages (
  id SERIAL PRIMARY KEY,
  space_id INTEGER REFERENCES wiki_spaces(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  slug VARCHAR(200) NOT NULL,
  content JSONB,
  content_html TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wiki_page_revisions (
  id SERIAL PRIMARY KEY,
  page_id INTEGER REFERENCES wiki_pages(id) ON DELETE CASCADE NOT NULL,
  version INTEGER NOT NULL,
  content JSONB,
  content_html TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wiki_comments (
  id SERIAL PRIMARY KEY,
  page_id INTEGER REFERENCES wiki_pages(id) ON DELETE CASCADE NOT NULL,
  author TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status_column_id);
