# 002 · DuckDB, Trino & Apache Parquet Integration — Implementation

**Date:** 2026-07-28 (implemented, commit `a9abc0f`)
**Status:** ✅ Implemented & verified
**Type:** Implementation
**Planning:** [`planning.md`](./planning.md)

---

## Overview

Two complementary analytical query engines in the local-dev-stack: **DuckDB**
(embedded OLAP — official CLI, file engine) and **Trino** (distributed SQL
query engine with built-in web UI), both with **Apache Parquet** file support.
Developers can query Parquet/CSV/JSON files directly without importing —
DuckDB for ad-hoc queries, Trino for federated multi-source analytics.

---

## Architecture

### Dual engine approach

```
┌──────────────────────┐     ┌──────────────────┐     ┌──────────────────────┐
│    DuckDB CLI        │     │   Trino Server    │     │   Hive Metastore     │
│   (lds/duckdev base) │     │ (trinodb/trino)   │     │  (apache/hive:4.0.0) │
│  No network port     │     │  Port 4451        │     │   Port 9083 (Thrift) │
│  (docker exec)       │     │  /ui (web console)│     │   (internal only)    │
└─────────┬────────────┘     └──────────┬────────┘     └──────────┬───────────┘
          │                             │                         │
          ▼                             ▼                         ▼
┌──────────────────┐     ┌──────────────────────┐     ┌──────────────────────┐
│ duckdb-data vol  │     │ data/trino/          │     │  Postgres (existing) │
│ data.duckdb +    │     │ *.parquet            │     │  lds_hive_metastore  │
│ data/duckdb/*    │     │ (via Hive connector) │     │  (table schemas)     │
└──────────────────┘     └──────────────────────┘     └──────────────────────┘
```

### Why two engines?

| Criteria | DuckDB | Trino |
|:---------|:-------|:------|
| **Setup** | Drop files in `data/duckdb/`, query immediately | Need to register tables in Hive Metastore first |
| **Query syntax** | `SELECT * FROM read_parquet('/data/file.parquet')` | `SELECT * FROM hive.schema.table` |
| **Federated queries** | No (single engine) | Yes — MySQL, Postgres, Kafka, Parquet in one SQL |
| **Web UI** | CLI only (docker exec) + DBGate GUI | Built-in at `http://localhost:4451/ui` |
| **JDBC/ODBC** | No native driver | Yes — `trino-jdbc-483.jar` bundled for Superset, Hop |
| **Resource usage** | Light (`256m`) | Moderate (`2g`) |
| **Best for** | Quick ad-hoc Parquet analysis | Multi-source analytics & BI tool integration |

### Profiles

| Profile | Toggle | Services | Port |
|:--------|:-------|:---------|:-----|
| `duckdb` | `LDS_ENABLE_DUCKDB` | `duckdb` (lds/duckdev base + CLI) | — (no port) |
| `trino` | `LDS_ENABLE_TRINO` | `trino`, `hive-metastore` (official images) | 4451 |

Both are **OFF by default** and join the `all` profile. `lds up duckdb trino`
starts them together; `lds up all` includes both.

---

## Implementation

### DuckDB

- **Image:** `lds/duckdev:${DUCKDB_VERSION}` base (DHI alpine-base + official
  DuckDB CLI binary) wrapped by `configs/duckdb/Dockerfile`. No custom
  server, no HTTP API — DuckDB is embedded like SQLite.
- **Usage:** `docker exec -it lds-duckdb duckdb /data/data.duckdb` or
  `docker exec lds-duckdb duckdb -c "SELECT ..." /data/data.duckdb`.
- **Persistence:** named volume `duckdb-data` mounted at `/data` — the
  `data.duckdb` file survives restarts. **Shared with DBGate**, whose DuckDB
  plugin opens the same file (read-only mode in the GUI to avoid file-lock
  contention).
- **Data directory:** `data/duckdb/` on the host → `/data/` inside the
  container. Drop `.parquet`, `.csv`, `.json` files there and query with
  `read_parquet('/data/filename.parquet')`.
- **Config:** minimal — just the Dockerfile (keeps the container alive with
  `tail -f /dev/null`).

### Trino

- **Image:** `trinodb/trino:${TRINO_VERSION}` (default `latest`), single-node
  (coordinator + worker in one process).
- **Connectors:** `hive` (Parquet via Hive Metastore), `tpch`, `tpcds` sample
  catalogs — add more via `configs/trino/catalog/`.
- **Data directory:** `data/trino/` — Parquet files registered as external
  tables (`fs.local.enabled=true`, tables point at `local:///data/trino/`).
- **Web UI:** `http://localhost:4451/ui` — query editor, history, cluster
  overview.
- **Config:** `configs/trino/config.properties` + `jvm.config` + catalog files.

### Hive Metastore

- **Image:** official `apache/hive:4.0.0` (pinned — no custom Dockerfile).
- **Startup:** entrypoint override in docker-compose.yml does:
  1. wait for `postgres:5432` (TCP probe, 30 × 2s)
  2. `schematool -dbType postgres -initOrUpgradeSchema` with retry (24 × 5s —
     bridges the race until the `lds_hive_metastore` DB exists)
  3. `exec hive --service metastore`
- **Database:** LDS Postgres — `lds_hive_metastore` DB / `app` user, created
  by `hive-metastore-init` (auto-run by `lds up trino`, injects the spec into
  `POSTGRES_INIT_SPECS`). JDBC driver mounted from
  `assets/jdbc/postgresql-42.7.4.jar` (`HIVE_METASTORE_POSTGRES_DRIVER`).
- **Exposed:** `9083` (Thrift) internal only — not published to the host.

### Seed data (`lds up` auto-runs)

`configs/seed-data/generate.py` (pandas + pyarrow, run through the existing
`lds/python-dev` image — zero new pulls) generates sample **Parquet, CSV and
JSONL** files into `data/duckdb/` and `data/trino/`:

- `sales.csv` / `sales.parquet` — 1k order rows
- `users.csv` / `users.parquet`, `products.csv`
- `events.jsonl` — 200 events
- Trino copies `sales.*` / `users.*` and adds `timeseries.parquet` (daily
  series 2024–2026 for federated-query examples)

Idempotent — skips files that already exist, never overwrites user data;
`scripts/run/seed-data.sh --force` regenerates. Wired into `up.sh`/`up.bat`
(profile `duckdb`/`trino`/`all`), runs **before** compose up so the files are
present when containers start.

---

## Port allocation

| Block | Service | Host | Internal | Notes |
|:------|:--------|:-----|:---------|:------|
| 4450–4459 | DuckDB | — | `duckdb:/data` | file engine — no network port |
| 4451 | Trino | `localhost:4451` | `trino:8080` | Web UI at `/ui` |
| 9083 | Hive Metastore | — | `hive-metastore:9083` | Thrift (internal only) |

> The analytical engines live in the `4450–4459` block, distinct from the
> realtime brokers (`4440–4449`) and admin tools (`4500–4530`).

---

## Files created

| File | Purpose |
|:-----|:--------|
| `configs/duckdb/Dockerfile` | Minimal wrapper around `lds/duckdev` base image |
| `configs/trino/config.properties` | Trino single-node server configuration |
| `configs/trino/jvm.config` | JVM settings |
| `configs/trino/catalog/hive.properties` | Hive connector for Parquet (thrift://hive-metastore:9083) |
| `configs/trino/catalog/tpch.properties` | TPCH sample data connector |
| `configs/trino/catalog/tpcds.properties` | TPCDS sample data connector |
| `configs/hive-metastore/metastore-site.xml` | Metastore config pointing to Postgres |
| `configs/hive-metastore/metastore-log4j2.properties` | Quiet logging |
| `configs/seed-data/generate.py` | Sample Parquet/CSV/JSONL generator |
| `scripts/run/seed-data.sh` / `.bat` | Seed CLI (idempotent, `--force` to regenerate) |
| `scripts/run/hive-metastore-init.sh` / `.bat` | Creates `lds_hive_metastore` DB via postgres-init |
| `data/duckdb/.gitkeep` | DuckDB data directory |
| `data/trino/.gitkeep` | Trino data directory |

---

## Env vars added

| Variable | Default | Description |
|:---------|:--------|:------------|
| `LDS_ENABLE_DUCKDB` | `false` | Enable DuckDB profile |
| `LDS_ENABLE_TRINO` | `false` | Enable Trino profile |
| `DUCKDB_VERSION` | `1.2.0` | DuckDB base image tag (pinned) |
| `DUCKDB_MEM_LIMIT` | `256m` | DuckDB container memory limit |
| `TRINO_VERSION` | `latest` | Trino image tag |
| `TRINO_HOST_PORT` | `4451` | Trino HTTP port |
| `TRINO_MEM_LIMIT` | `2g` | Trino container memory limit |
| `HIVE_METASTORE_POSTGRES_DB` | `lds_hive_metastore` | Metastore metadata DB |
| `HIVE_METASTORE_POSTGRES_USER` | `app` | Metastore DB user |
| `HIVE_METASTORE_POSTGRES_PASSWORD` | `app` | Metastore DB password |
| `HIVE_METASTORE_POSTGRES_DRIVER` | `postgresql-42.7.4.jar` | Postgres JDBC jar in `assets/jdbc/` |
| `HIVE_METASTORE_MEM_LIMIT` | `512m` | Metastore container memory limit |

---

## Documentation updates

| File | Update |
|:-----|:-------|
| `docs/en/12-ports.md` | Analytical engines block `4450–4459`: DuckDB (CLI only) + Trino (`:4451`) |
| `docs/id/12-ports.md` | Same (Indonesian) |
| `docs/en/13-profiles.md` | `duckdb` and `trino` profile rows |
| `docs/en/15-data-tools.md` | "Analytical query engines — DuckDB & Trino" section (+ Superset/Hop connection guides) |
| `CLAUDE.md` | `duckdb` / `trino` added to profiles list |
| `configs/web/dashboard/index.php` | Trino card (`:4451/ui`) + DuckDB card (no port → not probed) |

---

## Usage

```bash
# Start DuckDB (ad-hoc Parquet queries via CLI; seed data auto-runs)
./lds.sh up duckdb

# Query a Parquet file via docker exec
docker exec -it lds-duckdb duckdb /data/data.duckdb
docker exec lds-duckdb duckdb -c "SELECT * FROM read_parquet('/data/sales.parquet') LIMIT 10" /data/data.duckdb

# Start Trino (federated analytics; seeds data + metastore DB auto-runs)
./lds.sh up trino
# Open http://localhost:4451/ui in browser
#   SELECT * FROM tpch.tiny.orders LIMIT 10;
#   SELECT * FROM hive.default.sales LIMIT 10;   -- after registering the table

# Regenerate sample data (skips existing files by default)
./scripts/run/seed-data.sh --force

# Both together
./lds.sh up duckdb trino
```

---

## Verification (post-implementation)

- `docker compose --profile duckdb --profile trino config --quiet` passes
- `lds up duckdb trino` → seed-data runs first, files appear in `data/duckdb/`
  and `data/trino/`; hive-metastore-init creates `lds_hive_metastore`;
  `schematool` initializes the schema idempotently; metastore serves Thrift
  on `9083`
- Trino web UI answers at `http://localhost:4451/ui`; `tpch.tiny.orders`
  queries return rows
- Superset connects via `trino://trino:8080/hive/default` (driver auto-installed)

---

## Future considerations

- **Iceberg connector** — modern alternative to the Hive connector for Parquet
- **Auto-register seeded tables** — create Hive external tables for the seeded
  files on first start (currently a manual `CREATE TABLE` step)
- **Live query stats on the dashboard** — Trino card exists; enrich with
  per-engine health/query counters
- **OWL Ontology / AI Knowledge Base** — future planning (003)
