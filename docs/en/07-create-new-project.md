# 07 · Create a new project from a template

Making a new project = **copy a template, rename it, run it**. You never edit
`local-dev-stack`'s own files.

1. **Copy** a template anywhere (inside `templates/` or e.g. your language folder):
   ```bash
   cp -r templates/svc-template-go  D:/projects/Golang/orders
   ```
2. **Name it** — set `APP_HOST` in a `.env` next to the compose file, e.g.
   `APP_HOST=orders.test`.
3. **Run it:** `docker compose up -d` → `http://orders.test`.

**No `public/`/index page needed.** That applies only to plain PHP files in
`www/` (the shared mass-vhost). A template runs its own server and only needs to
listen on its `VIRTUAL_PORT`.

**No registration in LDS.** You do NOT add anything to LDS's `docker-compose.yml`.
New hostnames work automatically: `dns` resolves `*.test` by **wildcard** and
`proxy` **auto-discovers** any container that sets `VIRTUAL_HOST`.

**Standing requirements** (set once): `./lds.sh init` + adapter DNS → `127.0.0.1`;
keep `./lds.sh up proxy` running. Templates already join `lds-network` and set
`VIRTUAL_HOST`.

> Not changing system DNS? `lds hosts-sync` (admin/sudo) writes per-project hosts
> entries — but re-run it per new project (no wildcard).
