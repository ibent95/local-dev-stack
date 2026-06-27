# svc-template-django

Django **API** (Python framework + Django REST Framework), routed at
`http://svc-template-django.test`. The Django project is scaffolded into `./src`.

> Web counterpart: `web-template-django`. Native (no-framework) Python:
> `svc-template-python` / `web-template-python`.

## 1. Scaffold Django (once)

```bash
../../scripts/run/up.sh proxy
docker compose build
docker compose run --rm django bash -lc "rm -f .gitkeep && django-admin startproject config ."
```

Then add DRF to `src/config/settings.py` (`INSTALLED_APPS += ['rest_framework']`)
and **allow the host** for dev: `ALLOWED_HOSTS = ['*']`.

## 2. Run

```bash
docker compose up -d        # http://svc-template-django.test (runserver auto-reloads)
```

Point `settings.py` `DATABASES` at the stack: host `mysql`/`postgres`, etc.

## Production image

```bash
docker build --target prod -t svc-django:prod .   # gunicorn config.wsgi
```
