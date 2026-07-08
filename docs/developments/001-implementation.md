# 001 · LDS Custom Apps — Implementation

**Date:** 2026-07-06
**Status:** In Progress (Docker rebuild required)
**Type:** Implementation

---

## Overview

This document records the implementation details, bugs found, and fixes applied
during the bootstrap of the three LDS custom applications (Analytics, Tasks,
Wiki) and Vaultwarden integration.

---

## 1 · Tasks Completed

### 1.1 API Projects — Scaffolded & Working

All three APIs were scaffolded with the Hono + Drizzle ORM + SQLite stack:

| API | Source | Port | Status |
|-----|--------|------|--------|
| Analytics | `configs/analytics/api/` | 3001 | ✅ Working |
| Tasks | `configs/tasks/api/` | 3002 | ✅ Working |
| Wiki | `configs/wiki/api/` | 3003 | ✅ Working |

### 1.2 UI Projects — Scaffolded & Fixed

| UI | Framework | Port | Status |
|----|-----------|------|--------|
| Analytics | Nuxt 4 + Vue 3 + Tailwind v4 + Chart.js | 4173 | ✅ Fixed |
| Tasks | Angular 22 + Angular Material + CDK | 4174 | ✅ Fixed |
| Wiki | Next.js 16 + React 19 + Tailwind v4 | 4175 | ✅ Fixed |

### 1.3 Vaultwarden — Pre-existing

| Service | Port | Status |
|---------|------|--------|
| Vaultwarden | 8222 | ✅ Pre-configured in docker-compose.yml |

Vaultwarden was already configured in the stack prior to this cycle. No
code changes were required — the service uses the official `vaultwarden/server`
image with a volume mount for persistence.

---

## 2 · Bugs Found & Fixed

### 2.1 Tasks UI — 502 (TypeScript Build Error)

**Symptom:** `ng serve` fails with `TS5101: Option 'downlevelIteration' is deprecated`

**Root cause:** `@angular/build` was pinned to `^21.2.18` while all other
Angular packages were `^22.0.0`. The v21 build package internally injected
the deprecated `downlevelIteration` compiler option, which TypeScript 6.0
now rejects as a hard error.

**Fix:** Upgraded `@angular/build` from `^21.2.18` → `^22.0.0` in
`configs/tasks/ui/package.json` to match the rest of the Angular ^22 deps.

**Files changed:** `configs/tasks/ui/package.json`

---

### 2.2 Wiki UI — 504 (Server Crash Loop)

**Symptom:** Wiki UI returns 504 timeout; server logs show repeated crash-restart cycle.

**Root cause:** `src/app/globals.scss` contained `@import "tailwindcss"`. Sass
processed the `.scss` file and tried to resolve `tailwindcss` as a Sass module,
which failed. The Next.js dev server crashed on every request, restarting in a
loop. The proxy timed out (504) because the server never stabilized.

**Fix:**
- Created `src/app/globals.css` with `@import "tailwindcss"` (Tailwind v4 CSS syntax)
- Updated `src/app/layout.tsx` to import `./globals.css` instead of `./globals.scss`
- Deleted old `globals.scss`

**Additional fix:** Updated `next` from `^9.3.3` → `^16.2.10` in
`configs/wiki/ui/package.json` — the old version required `react@^16` but the
project uses React 19. Deleted stale `package-lock.json` that was pinning
`next@9.5.5`.

**Files changed:**
- `configs/wiki/ui/src/app/globals.css` (created)
- `configs/wiki/ui/src/app/globals.scss` (deleted)
- `configs/wiki/ui/src/app/layout.tsx`
- `configs/wiki/ui/package.json`

---

### 2.3 Analytics UI — Broken (Components Not Rendering)

**Symptom:** Dashboard shows empty/broken UI; Vue warnings about unresolved components.

**Root cause:** `index.vue` referenced five components that didn't exist.
Additionally, `recharts` is a React-only library and cannot render in Vue SFCs.

**Fix:**
- Created 5 missing Vue components in `app/components/`:
  - `StatCard.vue` — stat display card
  - `AnalyticsSection.vue` — section wrapper
  - `AnalyticsLineChart.vue` — line chart (vue-chartjs)
  - `AnalyticsBarChart.vue` — horizontal bar chart (vue-chartjs)
  - `AnalyticsPieChart.vue` — doughnut chart (vue-chartjs)
- Replaced `recharts` (React-only) with `chart.js` + `vue-chartjs` in package.json
- Fixed `app/assets/css/main.scss` — removed Tailwind v3 `@tailwind` directives
  (auto-injected by `@nuxtjs/tailwindcss` v6)
- Fixed `tailwind.config.js` — removed incorrect `content` paths that didn't
  account for Nuxt 4's `app/` directory structure

**Files changed:**
- `configs/analytics/ui/app/components/StatCard.vue` (created)
- `configs/analytics/ui/app/components/AnalyticsSection.vue` (created)
- `configs/analytics/ui/app/components/AnalyticsLineChart.vue` (created)
- `configs/analytics/ui/app/components/AnalyticsBarChart.vue` (created)
- `configs/analytics/ui/app/components/AnalyticsPieChart.vue` (created)
- `configs/analytics/ui/app/assets/css/main.scss`
- `configs/analytics/ui/app/tailwind.config.js`
- `configs/analytics/ui/package.json`

---

### 2.4 API Dependency Upgrades

All three LDS APIs share the same Hono-based stack. Upgraded to match the
reference project (`svc-learn-hono`):

| Package | Before | After |
|---------|--------|-------|
| `@hono/node-server` | `^1.13.0` | `^2.0.8` |
| `hono` | `^4.6.0` | `^4.12.27` |
| `drizzle-kit` (tasks/wiki) | `^0.18.1` | `^0.31.10` |

`drizzle-kit` in analytics was already at `^0.31.10`.

**Files changed:**
- `configs/analytics/api/package.json`
- `configs/tasks/api/package.json`
- `configs/wiki/api/package.json`

---

### 2.5 TypeScript Configuration Alignment

Updated `tsconfig.json` for all three APIs to align with the reference project:

| Option | Before | After |
|--------|--------|-------|
| `target` | `ES2022` | `ESNext` |
| `module` | `ESNext` | `NodeNext` |
| `moduleResolution` | `bundler` | *(implicit with NodeNext)* |
| `esModuleInterop` | `true` | *(removed — conflicts with verbatimModuleSyntax)* |
| `verbatimModuleSyntax` | — | `true` |
| `types` | — | `["node"]` |

Kept LDS-specific: `rootDir`, `declaration`, `declarationMap`, `sourceMap`,
`resolveJsonModule`, `forceConsistentCasingInFileNames`.

**Files changed:**
- `configs/analytics/api/tsconfig.json`
- `configs/tasks/api/tsconfig.json`
- `configs/wiki/api/tsconfig.json`

---

### 2.6 Dockerfile Fixes

Removed `--legacy-peer-deps` from `npm install` in all 6 Dockerfiles
(analytics-ui, tasks-ui, wiki-ui, analytics-api, tasks-api, wiki-api).

**Why:** `--legacy-peer-deps` prevented peer dependencies like `vite` (required
by `@nuxt/devtools`) from being installed. When `npm rebuild` triggered
`nuxt prepare`, it failed because `vite` was missing.

**Files changed:**
- `configs/analytics/ui/Dockerfile`
- `configs/analytics/api/Dockerfile`
- `configs/tasks/ui/Dockerfile`
- `configs/tasks/api/Dockerfile`
- `configs/wiki/ui/Dockerfile`
- `configs/wiki/api/Dockerfile`

---

### 2.7 Dashboard Fixes (index.php)

| Fix | Detail |
|-----|--------|
| Scheme-relative URLs | Project links changed from `http://` → `//` to support HTTPS overlay |
| Race condition | Cache write now uses `LOCK_EX` flag |
| Error suppression | Removed `@` on `file_get_contents` (redundant with `is_file()` check) |

**File changed:** `configs/web/dashboard/index.php`

---

### 2.8 Scripts Fixes

| File | Fix |
|------|-----|
| `scripts/run/up.sh` | Added auto-build check for `lds/node-dev` base image when analytics/tasks/wiki profiles are active |

**File changed:** `scripts/run/up.sh`

---

## 3 · Build Rebuild Required

All source changes are on disk but the Docker images are built via `COPY . .`
(not bind-mounted). A full rebuild is required:

```bash
docker compose --profile analytics --profile tasks --profile wiki build --no-cache
./lds.sh down analytics tasks wiki
./lds.sh up analytics tasks wiki
```

**Note:** The `--no-cache` flag is essential. Docker BuildKit caches Dockerfile
layers by content hash, but stale `package-lock.json` files from previous builds
can persist in the cache. Using `--no-cache` forces Docker to re-read every
Dockerfile and reinstall dependencies from scratch.

---

## 4 · Test Results

| App | Endpoint | Expected | Status |
|-----|----------|----------|--------|
| Analytics API | `GET /api/health` | `{"status":"ok"}` | ✅ Verified |
| Tasks API | `GET /api/health` | `{"status":"ok"}` | ✅ Verified |
| Wiki API | `GET /api/health` | `{"status":"ok"}` | ✅ Verified |
| Analytics UI | `http://analytics.test` | Dashboard renders | ⏳ Pending rebuild |
| Tasks UI | `http://tasks.test` | Kanban board renders | ⏳ Pending rebuild |
| Wiki UI | `http://wiki.test` | Wiki dashboard renders | ⏳ Pending rebuild |
