# svc-template-codeigniter

CodeIgniter 4 **API** (php-fpm on `lds/php` + nginx, docroot `public/`), routed
at `http://svc-template-codeigniter.test`.

> Web counterpart: `web-template-codeigniter`.

## 1. Scaffold (once)

```bash
../../scripts/run/up.sh proxy
docker compose build
docker compose run --rm app bash -lc "rm -f .gitkeep && composer create-project codeigniter4/appstarter ."
```

## 2. Run

```bash
docker compose up -d        # http://svc-template-codeigniter.test
```

Set DB in `src/app/Config/Database.php` (host `mysql`/`postgres`). Build API
routes/controllers as usual.

## Production image

```bash
docker build --target prod -t svc-codeigniter:prod .
```
