# svc-template-flask

Flask **API** (Python framework), `flask run --debug` hot-reload, routed at
`http://svc-template-flask.test`. Returns JSON.

> Web counterpart: `web-template-flask`. Native (no-framework) Python:
> `svc-template-python` / `web-template-python`.

## Run

```bash
../../scripts/run/up.sh proxy     # once
docker compose up -d              # http://svc-template-flask.test
```

Edit `app.py` — Flask reloads on save. Add deps to `requirements.txt`.

## Production image

```bash
docker build --target prod -t svc-flask:prod .   # runs gunicorn
```
