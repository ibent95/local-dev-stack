# svc-template-webman

Webman **API** (workerman-based, high-performance long-running PHP server — no
php-fpm/nginx), routed at `http://svc-template-webman.test` (listens on :8787).

> Web counterpart: `web-template-webman`.

## 1. Scaffold (once)

```bash
../../scripts/run/up.sh proxy
docker compose build
docker compose run --rm webman bash -lc "rm -f .gitkeep && composer create-project workerman/webman ."
```

## 2. Run

```bash
docker compose up -d        # http://svc-template-webman.test
```

Return JSON from `src/app/controller/IndexController.php`. After code changes,
restart: `docker compose restart webman` (or enable webman's file monitor).

## Production image

```bash
docker build --target prod -t svc-webman:prod .
```
