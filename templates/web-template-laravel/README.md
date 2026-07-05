# web-template-laravel

Laravel full-stack in **one container**, with **supervisord** orchestrating the
programs (php-fpm + nginx + queue + scheduler + Vite). Routed at
`http://web-template-laravel.test`.

> API counterpart: `svc-template-laravel`.

## Programs (toggle via env)

Each supervisord program starts only if its env var is `true` (defaults set in
the Dockerfile; override in `.env` or compose):

<table>
<thead>
<tr>
<th>Env var</th>
<th>Program</th>
<th>Default</th>
</tr>
</thead>
<tbody>
<tr>
<td>`ENABLE_PHP`</td>
<td>php-fpm</td>
<td>`true`</td>
</tr>
<tr>
<td>`ENABLE_NGINX`</td>
<td>nginx (serves `public/`)</td>
<td>`true`</td>
</tr>
<tr>
<td>`ENABLE_QUEUE`</td>
<td>`php artisan queue:work`</td>
<td>`false`</td>
</tr>
<tr>
<td>`ENABLE_SCHEDULER`</td>
<td>`php artisan schedule:run` loop</td>
<td>`false`</td>
</tr>
<tr>
<td>`ENABLE_VITE`</td>
<td>`npm run dev` (HMR)</td>
<td>`false`</td>
</tr>
</tbody>
</table>

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
