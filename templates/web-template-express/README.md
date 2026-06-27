# web-template-express

Node + Express + TypeScript **web app** (server-rendered HTML) with tsx watch
hot-reload, routed at `http://web-template-express.test`. The API counterpart is
`svc-template-express` (returns JSON). Native (no-framework) Node versions:
`svc-template-node` / `web-template-node` (http module).

## Run

```bash
../../scripts/run/up.sh proxy     # once
docker compose up -d              # http://web-template-express.test
```

Edit `src/index.ts` — tsx restarts on save.

## Make your own

Copy into `D:\projects\Typescript\my-web`, set `APP_HOST`, `docker compose up -d`.

## Production image

```bash
docker build --target prod -t my-web:prod .
```
