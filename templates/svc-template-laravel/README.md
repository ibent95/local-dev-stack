# svc-template-laravel

A standalone Laravel **API-only** project (PHP-FPM + nginx, no frontend),
routed at `http://svc-template-laravel.test` via the shared proxy.

## 1. Scaffold (once)

```bash
../../scripts/run/up.sh proxy
docker compose build
docker compose run --rm app bash -lc "rm -f .gitkeep && composer create-project laravel/laravel ."
# Enable API routes/scaffolding:
docker compose run --rm app php artisan install:api
```

## 2. Run

```bash
docker compose up -d        # http://svc-template-laravel.test
```

> Web counterpart: `web-template-laravel` (full-stack with Blade + Vite).

Point `src/.env` at the stack DB/Redis:

```env
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=app
DB_USERNAME=app
DB_PASSWORD=app
REDIS_HOST=redis
```

## Rename for a real project

Copy this folder, set `APP_HOST` (e.g. `orders-api.test`), scaffold, run.

## Production image

```bash
docker build --target prod -t svc-laravel:prod .
```
