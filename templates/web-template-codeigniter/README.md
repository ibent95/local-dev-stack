# web-template-codeigniter

CodeIgniter 4 **web app** (php-fpm on `lds/php` + nginx, docroot `public/`,
server-rendered views), routed at `http://web-template-codeigniter.test`.

> API counterpart: `svc-template-codeigniter`.

## 1. Scaffold (once)

```bash
../../scripts/run/up.sh proxy
docker compose build
docker compose run --rm app bash -lc "rm -f .gitkeep && composer create-project codeigniter4/appstarter ."
```

## 2. Run

```bash
docker compose up -d        # http://web-template-codeigniter.test
```

## Production image

```bash
docker build --target prod -t web-codeigniter:prod .
```
