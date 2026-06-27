# web-template-slim

Slim **web app** (micro-framework, php-fpm on `lds/php` + nginx, docroot
`public/`, server-rendered HTML), routed at `http://web-template-slim.test`.
Code is included in `src/`.

> API counterpart: `svc-template-slim`.

## Run

```bash
../../scripts/run/up.sh proxy
docker compose build
docker compose run --rm app composer install   # once (creates src/vendor)
docker compose up -d                            # http://web-template-slim.test
```

Edit `src/public/index.php`. For real views add a template engine (e.g.
`slim/twig-view`).

## Production image

```bash
docker build --target prod -t web-slim:prod .
```
