# svc-template-symfony

Symfony **API** (php-fpm on `lds/php` + nginx, docroot `public/`), routed at
`http://svc-template-symfony.test`.

> Web counterpart: `web-template-symfony` (full `webapp`).

## 1. Scaffold (once)

```bash
../../scripts/run/up.sh proxy
docker compose build
docker compose run --rm app bash -lc "rm -f .gitkeep && composer create-project symfony/skeleton ."
```

## 2. Run

```bash
docker compose up -d        # http://svc-template-symfony.test
```

Point `src/.env` `DATABASE_URL` at `mysql`/`postgres`. Add API tooling with
`composer require api` (API Platform) if you like.

## Production image

```bash
docker build --target prod -t svc-symfony:prod .
```
