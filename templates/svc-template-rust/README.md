# svc-template-rust

Rust HTTP service (axum + tokio) with **cargo-watch** hot-reload, routed via
nginx-proxy at `http://svc-template-rust.test`.

## Run

```powershell
../../scripts/run/up.sh proxy     # once
docker compose up -d               # http://svc-template-rust.test
```

First start compiles dependencies (slow); the `cargo-cache` / `target-cache`
volumes make later rebuilds fast. Edit `src/main.rs` — cargo-watch reruns.

## Make your own

Copy into `D:\projects\Rust\my-service`, set `APP_HOST`, `docker compose up -d`.

## Backing services

`mysql:3306`, `postgres:5432`, `redis:6379`, `kafka-broker:9092` on `lds-network`.
Add the relevant crate (e.g. `sqlx`, `redis`, `rdkafka`) to `Cargo.toml`.

## Production image

```powershell
docker build --target prod -t my-service:prod .
```
