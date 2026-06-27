# web-template-symfony

Symfony **web app** (php-fpm on `lds/php` + nginx, docroot `public/`, Twig +
assets via the `webapp` pack), routed at `http://web-template-symfony.test`.

> API counterpart: `svc-template-symfony`.

## 1. Scaffold (once)

```bash
../../scripts/run/up.sh proxy
docker compose build
docker compose run --rm app bash -lc "rm -f .gitkeep && composer create-project symfony/skeleton . && composer require webapp"
```

## 2. Run

```bash
docker compose up -d        # http://web-template-symfony.test
```

## Production image

```bash
docker build --target prod -t web-symfony:prod .
```
