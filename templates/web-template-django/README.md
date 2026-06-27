# web-template-django

Django **web app** (Python framework, server-rendered with Django templates),
routed at `http://web-template-django.test`. The Django project is scaffolded
into `./src`.

> API counterpart: `svc-template-django`. Native (no-framework) Python:
> `svc-template-python` / `web-template-python`.

## 1. Scaffold Django (once)

```bash
../../scripts/run/up.sh proxy
docker compose build
docker compose run --rm django bash -lc "rm -f .gitkeep && django-admin startproject config ."
```

Then **allow the host** for dev in `src/config/settings.py`:
`ALLOWED_HOSTS = ['*']`.

## 2. Run

```bash
docker compose up -d        # http://web-template-django.test (runserver auto-reloads)
```

Build views/templates as usual; point `DATABASES` at `mysql`/`postgres`.

## Production image

```bash
docker build --target prod -t web-django:prod .   # gunicorn config.wsgi
```
