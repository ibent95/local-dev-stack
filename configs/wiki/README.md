# LDS Wiki

A self-hosted knowledge base and documentation platform for your team. Built with **Next.js 16** (UI), **Hono** (API), **Drizzle ORM**, and **PostgreSQL**.

## Features

- **Spaces & Pages** — Organize documentation into spaces with optional categories and page pinning
- **Markdown Editor** — Write content with a live-preview markdown editor (`@uiw/react-md-editor`) that converts to HTML on save
- **Revision History** — Every edit creates a revision; view version history for any page
- **Comments** — Threaded comments on pages with author names
- **Tags** — Color-coded tags for pages (many-to-many)
- **Search** — Full-text search across page titles and content with relevance scoring
- **Published/Draft** — Toggle page visibility with the published flag

## Architecture

```
wiki/
├── ui/          # Next.js 16 frontend (port 4175)
│   ├── app/
│   │   ├── page.tsx                    # Home — list/create spaces
│   │   ├── spaces/[slug]/page.tsx      # Space — list pages, filter by category
│   │   ├── spaces/[slug]/new/page.tsx  # Create new page (markdown editor)
│   │   ├── spaces/[slug]/[pageSlug]/page.tsx    # View page content + comments
│   │   ├── spaces/[slug]/[pageSlug]/edit/page.tsx  # Edit page (markdown editor)
│   │   ├── search/page.tsx             # Search results
│   │   └── components/MarkdownEditor.tsx  # Reusable markdown editor component
│   └── lib/api.ts                      # API client with typed fetch helpers
├── api/         # Hono API server (port 3003)
│   ├── src/
│   │   ├── index.ts          # Entry point, CORS, route mounting
│   │   ├── db/schema.ts      # Drizzle schema (pages, spaces, categories, tags, revisions, comments)
│   │   └── routes/
│   │       ├── spaces.ts     # CRUD for spaces and categories
│   │       ├── pages.ts      # CRUD for pages, revisions, comments
│   │       └── search.ts     # Full-text search
│   └── drizzle.config.ts
├── Dockerfile
└── docker-compose.yml
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Next.js 16, React 19, Tailwind CSS 4, Lucide icons |
| Editor | `@uiw/react-md-editor` (markdown with live preview) |
| API | Hono (lightweight, edge-ready) |
| ORM | Drizzle ORM |
| Database | PostgreSQL (via LDS stack) |
| Rendering | Markdown → HTML via `marked` on save |

## API Endpoints

### Spaces

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/spaces` | List all spaces with page counts |
| `POST` | `/api/spaces` | Create a new space |
| `GET` | `/api/spaces/:slug` | Get space with categories |
| `PUT` | `/api/spaces/:slug` | Update a space |
| `DELETE` | `/api/spaces/:slug` | Delete a space |

### Pages

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/pages` | List pages (filter by `?space=` or `?category=`) |
| `POST` | `/api/pages` | Create a new page |
| `GET` | `/api/pages/:slug` | Get page with content, tags, comments |
| `PUT` | `/api/pages/:slug` | Update page (auto-creates revision) |
| `DELETE` | `/api/pages/:slug` | Delete a page |

### Comments

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/pages/:slug/comments` | Add a comment |

### Revisions

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/pages/:slug/revisions` | List revision history |
| `GET` | `/api/pages/:slug/revisions/:version` | Get a specific revision |

### Search

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/search?q=term` | Full-text search across pages |

## Running

The Wiki runs as part of the LDS stack. Enable it in your `.env`:

```bash
LDS_ENABLE_WIKI=true
```

Or start it standalone:

```bash
cd configs/wiki
docker compose up --build
```

- **UI**: http://localhost:4175
- **API**: http://localhost:3003

### Development

```bash
# API
cd configs/wiki/api
npm install
npm run dev

# UI
cd configs/wiki/ui
npm install
npm run dev
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | — | PostgreSQL connection string |
| `API_URL` | `http://localhost:3003` | API base URL (UI rewrites `/api/*` to this) |
