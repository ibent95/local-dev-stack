# web-template-cakephp

CakePHP **web app** (php-fpm on `lds/php` + nginx, docroot `webroot/`,
server-rendered views), routed at `http://web-template-cakephp.test`.

> API counterpart: `svc-template-cakephp`.

## 1. Scaffold (once)

```bash
../../scripts/run/up.sh proxy
docker compose build
docker compose run --rm app bash -lc "rm -f .gitkeep && composer create-project cakephp/app ."
```

## 2. Run

```bash
docker compose up -d        # http://web-template-cakephp.test
```

## Production image

```bash
docker build --target prod -t web-cakephp:prod .
```
