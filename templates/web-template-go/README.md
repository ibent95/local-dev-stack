# web-template-go

Go **web app** (server-rendered HTML via `html/template`) with air hot-reload,
routed at `http://web-template-go.test`. The API counterpart is
`svc-template-go` (returns JSON).

## Run

```bash
../../scripts/run/up.sh proxy     # once (Windows cmd: ..\..\scripts\run\up.bat proxy)
docker compose up -d              # http://web-template-go.test
```

Edit `main.go` — air rebuilds on save.

## Make your own

Copy into `D:\projects\Golang\my-web`, set `APP_HOST`, `docker compose up -d`.

## Backing services

`mysql:3306`, `postgres:5432`, `redis:6379`, `kafka-broker:9092` on `lds-network`.

## Production image

```bash
docker build --target prod -t my-web:prod .
```
