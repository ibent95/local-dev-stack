# svc-template-go

Go HTTP service (stdlib `net/http`) with **air** hot-reload, routed via
nginx-proxy at `http://svc-template-go.test`.

## Run

```powershell
# 1) Make sure the stack proxy + DNS are up (once):
../../scripts/run/up.sh proxy

# 2) Start this app:
docker compose up -d         # http://svc-template-go.test
```

Edit `main.go` — air rebuilds on save.

## Make your own

1. Copy this folder into `D:\projects\Golang\my-service`.
2. Set `APP_HOST` (e.g. `my-service.test`) in `.env` or the compose file.
3. `docker compose up -d` → `http://my-service.test`.

## Backing services

Reachable by hostname on `lds-network`: `mysql:3306`, `postgres:5432`,
`redis:6379`, `kafka-broker:9092`, `schema-registry:8080`.

## Production image

```powershell
docker build --target prod -t my-service:prod .
```
