# web-template-angular

A standalone Angular SPA, dev server routed at `http://web-template-angular.test` via the
shared proxy. The real Angular app is generated into `./src` once.

## 1. Scaffold Angular (once)

```bash
../../scripts/run/up.sh proxy        # (Windows cmd: ..\..\..\scripts\run\up.bat proxy)

# Generate a fresh Angular app into ./src (run from this folder):
docker run --rm -it -v "$(pwd)/src:/app" -w /app node:22-bookworm \
  npx -y @angular/cli@latest new app --directory . --defaults --skip-git
```

## 2. Run

```powershell
docker compose up -d        # installs deps + ng serve -> http://web-template-angular.test
docker compose logs -f app  # watch the first npm install / compile
```

Edit files in `src/` — Angular hot-reloads.

## Talking to a backend

Call your API by its hostname, e.g. `http://svc-template-laravel.test` or
`http://svc-template-go.test`. To avoid CORS in dev, use Angular's proxy
(`proxy.conf.json`) so `/api` is forwarded to the backend.

## Notes

- If the browser shows **"Invalid Host header"**, the `--disable-host-check`
  flag in the Dockerfile handles it; on newer Angular set `allowedHosts` in the
  `serve` options of `angular.json` instead.
- HMR websockets pass through the proxy automatically.

## Production image

```powershell
docker build --target prod -t angular-app:prod .   # static files via nginx
```
