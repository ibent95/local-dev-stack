# svc-template-fastapi

FastAPI **API** (Python framework, async), `uvicorn --reload` hot-reload, routed
at `http://svc-template-fastapi.test`. Returns JSON. Interactive docs at `/docs`.

> Web counterpart: `web-template-fastapi`. Native (no-framework) Python:
> `svc-template-python` / `web-template-python`.

## Run

```bash
../../scripts/run/up.sh proxy     # once
docker compose up -d              # http://svc-template-fastapi.test
```

Edit `main.py` — uvicorn reloads on save. Add deps to `requirements.txt`.

## Production image

```bash
docker build --target prod -t svc-fastapi:prod .
```
