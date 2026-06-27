# web-template-webman

Webman **web app** (workerman-based long-running PHP server — no php-fpm/nginx),
routed at `http://web-template-webman.test` (listens on :8787).

> API counterpart: `svc-template-webman`.

## 1. Scaffold (once)

```bash
../../scripts/run/up.sh proxy
docker compose build
docker compose run --rm webman bash -lc "rm -f .gitkeep && composer create-project workerman/webman ."
```

## 2. Run

```bash
docker compose up -d        # http://web-template-webman.test
```

Render HTML/views from `src/app/controller/`. Restart after changes:
`docker compose restart webman`.

## Production image

```bash
docker build --target prod -t web-webman:prod .
```
