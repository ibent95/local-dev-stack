---
name: local-dev-stack
description: >
  Operate the local-dev-stack shared Docker Compose environment via the `lds`
  CLI — start/stop profiles, manage the bundled tools (DrawDB, Apache Hop,
  Superset, Semgrep, Kafka, the databases), sync *.test hosts, and apply known
  fixes. Use when working in this repo or when the user asks to run, configure,
  or troubleshoot the stack, its tools, or its `<name>.test` URLs.
---

# Local Dev Stack

A profile-gated Docker Compose stack driven by the `lds` wrapper. Use
`./lds.sh <cmd>` (bash) or `lds.bat <cmd>` (Windows). Every service joins the
external network `lds-network`; web UIs are routed `<name>.test` by an
nginx-proxy edge + a dnsmasq `*.test` resolver.

## Golden rules

- **Don't build/pull unprompted.** Image pulls are slow/flaky here; the user
  runs the heavy builds. For verification, prefer reading config or a single
  container check over a full `up`.
- **Profiles, not bare compose.** Start things with `lds up <profile…>` (no args
  = the `LDS_ENABLE_*=true` toggles in `.env`). `lds up all` is heavy.
- After editing `docker-compose.yml`, validate with `docker compose config --quiet`.
- Reach services *inside* the network by **container/service name**
  (`lds-mysql:3306`, `lds-postgres:5432`, `kafka-broker:9092`), not `localhost`.

## Commands

```
lds up [profiles…]        start (default = enabled toggles, else all)
lds start [profiles…]     full lifecycle: init → down → rm → build-bases? → up
lds stop | down [-v]      stop+keep | remove (-v wipes volumes)
lds ps | logs [service]   status | tail logs
lds exec <svc> [cmd…]     shell/command in a container
lds hosts-sync            write projects + tool hosts into the hosts file (admin)
lds db init [mysql|mongo|all] | seed     create `app` db/users | DBGate conns
lds kafka topics | connect-plugin [--generic] <name> | register-connectors | init
lds tools semgrep [path]  run a Semgrep scan → configs/semgrep/reports/report.sarif
lds certs [--force]       mint the wildcard *.test dev TLS cert (LDS_ENABLE_HTTPS)
```

Old flat names (`kafka-topics`, `mysql-init`, `mongo-init`, `register-connectors`,
`connect-plugin`, `dbgate-seed`) still work as aliases.

## Layout / ordering

`docker-compose.yml` is ordered by importance of usage: **web foundation**
(proxy, dns, php) → **databases** (mysql, postgres, mongo, redis, memcached) →
**admin UIs** (phpcacheadmin, dbgate) → **data tools** (drawdb, hop, superset,
semgrep) → **realtime brokers** (soketi, centrifugo, emqx) → **Kafka** (last,
heaviest, off by default). Each group has a `# ===` banner. Host ports live in
the `44xx` block (see `docs/en/12-ports.md`).

## Dashboard

`http://localhost` is a PHP control panel (`configs/web/dashboard/index.php`,
mounted at `/var/lds-dashboard` *outside* the project path — so there is no
`__dashboard.test`). It lists tools (grouped, with live ●/○ probes), projects,
and backing-service status. Edit `index.php` to add/regroup tool cards; it's
bind-mounted, so changes are live (no restart).

## Known gotchas & fixes

- **DrawDB blank page** → open `http://localhost:4423`, NOT `drawdb.test`. It
  calls `crypto.randomUUID()`, exposed only in a secure context (localhost or
  HTTPS). The dashboard links it to the localhost port for this reason.
- **Apache Hop** → use image `apache/hop-web` (Tomcat, no login, served at
  `/ui`), NOT `apache/hop` (headless hop-server, Basic auth). MySQL Connector/J
  isn't bundled (GPL) — it's single-file-mounted from `configs/hop/jdbc-drivers/`
  (`HOP_MYSQL_DRIVER` in `.env`; see the README there to fetch the jar). Postgres
  is bundled; Kafka uses bundled *transforms*; Mongo/Redis have no JDBC driver.
  The session timeout is set to never expire via a `command` wrapper.
- **Superset 502 / "readonly database"** → the `superset-home` volume is owned by
  a stale UID (e.g. 1000 from the old upstream image); the DHI image runs as
  65532. Fix: `docker volume rm local-dev-stack_superset-home` (or chown it to
  65532), then recreate. Login `admin`/`admin`.
- **Semgrep** = two services: `semgrep` (nginx viewer at `semgrep.test`, serving
  `configs/semgrep/reports/`) and `semgrep-scan` (pinned `semgrep/semgrep` CLI in
  its own run-only profile — never auto-starts). `lds tools semgrep [path]` runs
  that pinned image via `docker run -v <path>:/src` → `report.sarif`; then refresh
  the viewer. (Not `docker compose run` — Compose's -v splits on ':' and chokes on
  Windows `D:\…` paths, leaving /src empty.) Empty viewer = no scan has run yet.
  `lds up semgrep` pre-pulls the scanner image (best-effort).
- **DB `app` database missing** (DHI mysql/mongo don't honor the usual init env)
  → `lds db init mysql|mongo|all` (auto-run by `lds up`).
- **`*.test` won't resolve** without the dns container as your resolver → run
  `lds hosts-sync` (admin/sudo) to write the hosts file; `localhost` needs no entry.

## Docs

Full reference in `docs/en/` (and `docs/id/`): `04-commands`, `12-ports`,
`13-profiles`, `15-data-tools` (the tools + dashboard), plus `CLAUDE.md` for an
architecture summary.
