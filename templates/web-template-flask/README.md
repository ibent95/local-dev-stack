# web-template-flask

Flask **web app** (Python framework), server-rendered HTML, `flask run --debug`
hot-reload, routed at `http://web-template-flask.test`.

> API counterpart: `svc-template-flask`. Native (no-framework) Python:
> `svc-template-python` / `web-template-python`.

## Run

```bash
../../scripts/run/up.sh proxy     # once
docker compose up -d              # http://web-template-flask.test
```

Edit `app.py` — Flask reloads on save. For real templates, add a `templates/`
dir and use `render_template`.

## Production image

```bash
docker build --target prod -t web-flask:prod .   # runs gunicorn
```
