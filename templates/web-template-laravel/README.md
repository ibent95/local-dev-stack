# web-template-laravel

Laravel full-stack in **one container**, with **supervisord** orchestrating the
programs (php-fpm + nginx + queue + scheduler + Vite). Routed at
`http://web-template-laravel.test`.

> API counterpart: `svc-template-laravel`.

## Programs (toggle via env)

Each supervisord program starts only if its env var is `true` (defaults set in
the Dockerfile; override in `.env` or compose):

| Env var | Program | Default |
|---------|---------|---------|
| `ENABLE_PHP` | php-fpm | `true` |
| `ENABLE_NGINX` | nginx (serves `public/`) | `true` |
| `ENABLE_QUEUE` | `php artisan queue:work` | `false` |
| `ENABLE_SCHEDULER` | `php artisan schedule:run` loop | `false` |
| `ENABLE_VITE` | `npm run dev` (HMR) | `false` |

## 1. Scaffold Laravel (once)

```bash
../../scripts/run/up.sh proxy
docker compose build
docker compose run --rm app bash -lc "rm -f .gitkeep && composer create-project laravel/laravel ."
```

## 2. Run

```bash
docker compose up -d                       # web only
ENABLE_QUEUE=true ENABLE_SCHEDULER=true docker compose up -d   # + workers
```

Point `src/.env` at the stack DB/Redis (host `mysql`/`postgres`/`redis`). All
program logs stream to `docker compose logs -f app`.

## Production image

```bash
docker build --target prod -t web-laravel:prod .
```
