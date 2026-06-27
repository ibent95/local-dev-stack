# svc-template-express

Node + Express + TypeScript service with **tsx watch** hot-reload, routed via
nginx-proxy at `http://svc-template-express.test`.

## Run

```powershell
../../scripts/run/up.sh proxy     # once
docker compose up -d               # http://svc-template-express.test
```

Edit `src/index.ts` — tsx restarts on save. The anonymous `node_modules`
volume keeps host/container deps from clashing.

## Make your own

Copy into `D:\projects\Typescript\my-service`, set `APP_HOST`,
`docker compose up -d`.

## Backing services

`mysql:3306`, `postgres:5432`, `redis:6379`, `kafka-broker:9092` on `lds-network`
(add `mysql2`, `pg`, `ioredis`, `kafkajs` as needed).

## Production image

```powershell
docker build --target prod -t my-service:prod .
```
