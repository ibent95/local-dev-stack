# web-template-rust

Rust **web app** (axum, server-rendered HTML) with cargo-watch hot-reload,
routed at `http://web-template-rust.test`. The API counterpart is
`svc-template-rust` (returns JSON).

## Run

```bash
../../scripts/run/up.sh proxy     # once
docker compose up -d              # http://web-template-rust.test
```

First start compiles deps (slow); the cache volumes speed up later rebuilds.
Edit `src/main.rs` — cargo-watch reruns.

## Make your own

Copy into `D:\projects\Rust\my-web`, set `APP_HOST`, `docker compose up -d`.

## Production image

```bash
docker build --target prod -t my-web:prod .
```
