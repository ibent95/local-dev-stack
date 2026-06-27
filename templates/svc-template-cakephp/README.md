# svc-template-cakephp

CakePHP **API** (php-fpm on `lds/php` + nginx, docroot `webroot/`), routed at
`http://svc-template-cakephp.test`.

> Web counterpart: `web-template-cakephp`.

## 1. Scaffold (once)

```bash
../../scripts/run/up.sh proxy
docker compose build
docker compose run --rm app bash -lc "rm -f .gitkeep && composer create-project cakephp/app ."
```

## 2. Run

```bash
docker compose up -d        # http://svc-template-cakephp.test
```

Set DB in `src/config/app_local.php` (host `mysql`/`postgres`). Build API with
`bin/cake bake`.

## Production image

```bash
docker build --target prod -t svc-cakephp:prod .
```
