# web-template-python

Python **web app** using the native stdlib `http.server` (no framework),
server-rendered HTML, `watchfiles` hot-reload, routed at
`http://web-template-python.test`.

> API counterpart: `svc-template-python`. (Framework templates can be added —
> Flask / Django / FastAPI.)

## Run

```bash
../../scripts/run/up.sh proxy     # once
docker compose up -d              # http://web-template-python.test
```

Edit `main.py` — watchfiles restarts on save.

## Production image

```bash
docker build --target prod -t web-python:prod .
```
