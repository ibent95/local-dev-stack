# web-template-react

A standalone React + Vite + TypeScript SPA, dev server routed at
`http://web-template-react.test` via the shared proxy. The real app is generated into
`./src` once.

## 1. Scaffold React (once)

```bash
../../scripts/run/up.sh proxy        # (Windows cmd: ..\..\..\scripts\run\up.bat proxy)

# Generate React + Vite + TS into ./src (run from this folder):
docker run --rm -it -v "$(pwd)/src:/app" -w /app node:22-bookworm-slim \
  sh -c "npm create vite@latest . -- --template react-ts"
```

## 2. Allow the .test host (once)

Vite blocks unknown hosts in recent versions. In `src/vite.config.ts`, set:

```ts
export default defineConfig({
  plugins: [react()],
  server: { host: true, allowedHosts: ['.test'] },
})
```

## 3. Run

```powershell
docker compose up -d        # installs deps + vite -> http://web-template-react.test
docker compose logs -f app
```

Edit files in `src/` — Vite HMR updates the browser.

## Talking to a backend

Call your API by hostname (`http://svc-template-laravel.test`, `http://svc-template-go.test`),
or configure `server.proxy` in `vite.config.ts` to forward `/api` to it.

## Production image

```powershell
docker build --target prod -t react-app:prod .   # static files via nginx
```
