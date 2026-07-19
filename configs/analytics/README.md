# LDS Analytics

A self-hosted, privacy-first web analytics dashboard. Built with **Nuxt 4** (UI), **Hono** (API), **Drizzle ORM**, and **PostgreSQL**.

## Features

- **Site Management** — Register multiple sites/domains to track
- **Pageview Tracking** — Daily pageview counts with time-series charts
- **Top Pages** — Most visited pages ranked by view count
- **Visitor Metrics** — Unique visitors (by day), average screen width
- **Referrer Analysis** — Top referrer sources
- **Geographic Data** — Visitors by country
- **Device & Browser Breakdown** — Desktop/mobile/tablet and browser distribution
- **Live Event Feed** — Recent events table with page, device, browser, and country info
- **Date Range Filtering** — Query any time period via `since`/`until` params (defaults to last 30 days)

## Architecture

```
analytics/
├── ui/          # Nuxt 4 frontend (port 4173)
│   ├── app/
│   │   ├── pages/index.vue              # Main dashboard with all charts
│   │   ├── composables/useAnalytics.ts  # Reactive data fetching composable
│   │   └── components/
│   │       ├── AnalyticsLineChart.vue   # Pageviews over time
│   │       ├── AnalyticsBarChart.vue    # Top pages bar chart
│   │       ├── AnalyticsPieChart.vue    # Device/browser pie charts
│   │       ├── AnalyticsSection.vue     # Reusable section wrapper
│   │       └── StatCard.vue             # Overview stat cards
│   └── types/api.ts                     # TypeScript interfaces
├── api/         # Hono API server
│   ├── src/
│   │   ├── index.ts          # Entry point, CORS, route mounting
│   │   ├── db/schema.ts      # Drizzle schema (sites, events)
│   │   └── routes/
│   │       ├── sites.ts      # Site CRUD
│   │       ├── analytics.ts  # All analytics queries (overview, pageviews, top-pages, etc.)
│   │       └── track.ts      # Event ingestion endpoint
│   └── drizzle.config.ts
├── Dockerfile
└── docker-compose.yml
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Nuxt 4, Vue 3, Tailwind CSS, Chart.js + vue-chartjs |
| Icons | Lucide Vue Next |
| API | Hono (lightweight, edge-ready) |
| ORM | Drizzle ORM |
| Database | PostgreSQL (via LDS stack) |

## Tracking Integration

To track a site, add the tracking snippet to your HTML:

```html
<script
  data-site-id="YOUR_SITE_UUID"
  src="http://localhost:3004/track.js"
  defer
></script>
```

The script auto-captures:
- Page path (`pathname`)
- Referrer (`document.referrer`)
- Screen width (`screen.width`)
- User agent → device (desktop/mobile/tablet), browser, OS

## API Endpoints

### Sites

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/sites` | List all tracked sites |
| `POST` | `/api/sites` | Register a new site (`{ domain, name }`) |
| `GET` | `/api/sites/:id` | Get a single site |
| `DELETE` | `/api/sites/:id` | Delete a site |

### Analytics (all scoped to a site)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/analytics/:siteId/overview` | High-level stats (pageviews, unique visitors, avg screen) |
| `GET` | `/api/analytics/:siteId/pageviews` | Pageview count by day |
| `GET` | `/api/analytics/:siteId/top-pages` | Most visited pages |
| `GET` | `/api/analytics/:siteId/referrers` | Top referrer sources |
| `GET` | `/api/analytics/:siteId/countries` | Visitors by country |
| `GET` | `/api/analytics/:siteId/devices` | Device breakdown (desktop/mobile/tablet) |
| `GET` | `/api/analytics/:siteId/browsers` | Browser breakdown |
| `GET` | `/api/analytics/:siteId/recent` | Recent events (live feed) |

**Date filtering** — All analytics endpoints accept optional `?since=` and `?until=` query params (ISO 8601 dates). Defaults to the last 30 days.

### Event Ingestion

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/track` | Ingest a pageview event |

## Running

The Analytics tool runs as part of the LDS stack. Enable it in your `.env`:

```bash
LDS_ENABLE_ANALYTICS=true
```

Or start it standalone:

```bash
cd configs/analytics
docker compose up --build
```

- **UI**: http://localhost:4173
- **API**: http://localhost:3004

### Development

```bash
# API
cd configs/analytics/api
npm install
npm run dev

# UI
cd configs/analytics/ui
npm install
npm run dev
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | — | PostgreSQL connection string |
