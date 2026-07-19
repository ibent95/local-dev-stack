# LDS Tasks

A self-hosted project management tool with kanban boards, workspaces, and an integrated wiki. Built with **Angular 22** (UI), **Hono** (API), **Drizzle ORM**, and **PostgreSQL**.

## Features

- **Workspaces** — Top-level containers for organizing projects
- **Projects** — Each project has its own kanban board, columns, labels, and tasks
- **Kanban Board** — Drag-and-drop task management with custom status columns (CDK drag-drop)
- **Tasks** — Title, description, priority (low/medium/high/urgent), assignee, due date, labels
- **Labels** — Color-coded labels for tasks (many-to-many)
- **Status Columns** — Custom per-project columns with drag-and-drop reordering
- **Comments** — Threaded comments on tasks with author names
- **Wiki Spaces** — Built-in wiki pages per workspace for documentation
- **Revision History** — Page version tracking for wiki content

## Architecture

```
tasks/
├── ui/          # Angular 22 frontend (port 4174)
│   └── src/app/
│       ├── pages/
│       │   ├── dashboard/              # Workspace/project list
│       │   ├── project-board/          # Kanban board with drag-drop
│       │   └── task-detail/            # Task detail with comments
│       ├── services/api.service.ts     # HTTP client for all API calls
│       ├── models/task.models.ts       # TypeScript interfaces
│       └── app.routes.ts              # Route definitions
├── api/         # Hono API server
│   ├── src/
│   │   ├── index.ts          # Entry point, CORS, route mounting
│   │   ├── db/schema.ts      # Drizzle schema (workspaces, projects, tasks, labels, wiki)
│   │   └── routes/
│   │       ├── workspaces.ts # Workspace CRUD
│   │       ├── projects.ts   # Project CRUD, status columns, labels
│   │       ├── tasks.ts      # Task CRUD, comments
│   │       └── wiki.ts       # Wiki spaces and pages
│   └── drizzle.config.ts
├── Dockerfile
└── docker-compose.yml
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Angular 22, Tailwind CSS, Angular CDK (drag-drop) |
| API | Hono (lightweight, edge-ready) |
| ORM | Drizzle ORM |
| Database | PostgreSQL (via LDS stack) |

## API Endpoints

### Workspaces

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/workspaces` | List all workspaces |
| `POST` | `/api/workspaces` | Create a workspace |
| `GET` | `/api/workspaces/:slug` | Get workspace with projects |

### Projects

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/workspaces/:wsSlug/projects` | Create a project |
| `GET` | `/api/projects/:id` | Get project with columns and labels |

### Tasks

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/projects/:projectId/tasks` | List tasks (filter by `?statusColumnId=`) |
| `POST` | `/api/projects/:projectId/tasks` | Create a task |
| `GET` | `/api/tasks/:id` | Get task with labels and comments |
| `PATCH` | `/api/tasks/:id` | Update task fields |
| `DELETE` | `/api/tasks/:id` | Delete a task |

### Task Comments

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/tasks/:id/comments` | Add a comment |
| `DELETE` | `/api/tasks/:taskId/comments/:commentId` | Delete a comment |

### Status Columns

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/projects/:projectId/status-columns` | Create a column |
| `DELETE` | `/api/projects/:projectId/status-columns/:colId` | Delete a column |

### Labels

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/projects/:projectId/labels` | Create a label |
| `DELETE` | `/api/projects/:projectId/labels/:labelId` | Delete a label |

### Wiki

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/workspaces/:wsSlug/wiki` | List wiki spaces |
| `POST` | `/api/wiki-spaces` | Create a wiki space |
| `GET` | `/api/wiki-spaces/:slug` | Get wiki space with pages |
| `POST` | `/api/wiki-pages` | Create a wiki page |
| `GET` | `/api/wiki-pages/:slug` | Get wiki page |
| `PUT` | `/api/wiki-pages/:slug` | Update wiki page (creates revision) |

## Running

The Tasks tool runs as part of the LDS stack. Enable it in your `.env`:

```bash
LDS_ENABLE_TASKS=true
```

Or start it standalone:

```bash
cd configs/tasks
docker compose up --build
```

- **UI**: http://localhost:4174
- **API**: http://localhost:3002

### Development

```bash
# API
cd configs/tasks/api
npm install
npm run dev

# UI
cd configs/tasks/ui
npm install
npm start
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | — | PostgreSQL connection string |
