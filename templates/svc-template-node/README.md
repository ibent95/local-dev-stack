# svc-template-node

Node **API** using the native `http` module (no framework) + TypeScript, with
tsx watch hot-reload, routed at `http://svc-template-node.test`. Returns JSON.

> Web counterpart: `web-template-node`. Framework version: `svc-template-express`.

## Run

```bash
../../scripts/run/up.sh proxy     # once
docker compose up -d              # http://svc-template-node.test
```

Edit `src/index.ts` — tsx restarts on save.

## Backing services

`mysql:3306`, `postgres:5432`, `redis:6379`, `kafka-broker:9092` on `lds-network`.

## Production image

```bash
docker build --target prod -t svc-node:prod .
```
