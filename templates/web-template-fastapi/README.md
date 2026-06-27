# web-template-fastapi

FastAPI **web app** (Python framework), server-rendered HTML via `HTMLResponse`,
`uvicorn --reload` hot-reload, routed at `http://web-template-fastapi.test`.

> API counterpart: `svc-template-fastapi`. Native (no-framework) Python:
> `svc-template-python` / `web-template-python`.

## Run

```bash
../../scripts/run/up.sh proxy     # once
docker compose up -d              # http://web-template-fastapi.test
```

Edit `main.py` — uvicorn reloads on save. For richer views, add `jinja2` and use
`Jinja2Templates`.

## Production image

```bash
docker build --target prod -t web-fastapi:prod .
```
