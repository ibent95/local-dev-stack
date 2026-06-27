# svc-template-slim

Slim **API** (micro-framework, php-fpm on `lds/php` + nginx, docroot `public/`),
routed at `http://svc-template-slim.test`. Code is included in `src/`.

> Web counterpart: `web-template-slim`.

## Run

```bash
../../scripts/run/up.sh proxy
docker compose build
docker compose run --rm app composer install   # once (creates src/vendor)
docker compose up -d                            # http://svc-template-slim.test
```

Edit `src/public/index.php`; add deps to `src/composer.json`.

## Production image

```bash
docker build --target prod -t svc-slim:prod .
```
