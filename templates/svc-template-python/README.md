# svc-template-python

Python **API** using the native stdlib `http.server` (no framework), with
`watchfiles` hot-reload, routed at `http://svc-template-python.test`. Returns JSON.

> Web counterpart: `web-template-python`. (Framework templates can be added —
> Flask / Django / FastAPI.)

## Run

```bash
../../scripts/run/up.sh proxy     # once
docker compose up -d              # http://svc-template-python.test
```

Edit `main.py` — watchfiles restarts on save.

## Backing services

`mysql:3306`, `postgres:5432`, `redis:6379`, `kafka-broker:9092` on `lds-network`.

## Production image

```bash
docker build --target prod -t svc-python:prod .
```
