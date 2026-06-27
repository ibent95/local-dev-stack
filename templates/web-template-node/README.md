# web-template-node

Node **web app** using the native `http` module (no framework) + TypeScript,
server-rendered HTML, tsx watch hot-reload, routed at
`http://web-template-node.test`.

> API counterpart: `svc-template-node`. Framework version: `web-template-express`.

## Run

```bash
../../scripts/run/up.sh proxy     # once
docker compose up -d              # http://web-template-node.test
```

Edit `src/index.ts` — tsx restarts on save.

## Production image

```bash
docker build --target prod -t web-node:prod .
```
