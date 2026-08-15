# 002 · DuckDB, Trino & Apache Parquet Integration — Planning

**Date:** 2026-07-22
**Status:** Implemented (see [`implementation.md`](./implementation.md))
**Type:** Planning

---

## Overview

Introduce two complementary analytical query engines to the local-dev-stack:
**DuckDB** (embedded OLAP — official CLI image) and **Trino** (distributed
SQL query engine), both with **Apache Parquet** file support. Developers can
query Parquet/CSV/JSON files directly without importing — DuckDB for ad-hoc
queries, Trino for federated multi-source analytics.

---

## Architecture

### Dual engine approach

```
┌──────────────────────┐     ┌──────────────────┐     ┌──────────────────────┐
│    DuckDB CLI        │     │   Trino Server    │     │   Hive Metastore     │
│  (official image)    │     │ (trinodb/trino)   │     │   (Apache Hive)      │
│  No network port     │     │  Port 4451        │     │   Port 9083 (Thrift) │
│  (docker exec)       │     │  /ui (web console)│     │   (internal only)    │
└─────────┬────────────┘     └──────────┬────────┘     └──────────┬───────────┘
          │                             │                         │
          ▼                             ▼                         ▼
┌──────────────────┐     ┌──────────────────────┐     ┌──────────────────────┐
│ data/duckdb/     │     │ data/trino/          │     │  Postgres (existing)  │
│ *.parquet, *.csv │     │ *.parquet            │     │  lds_hive_metastore DB    │
│ *.json, *.arrow  │     │ (via Hive connector) │     │  (table schemas)      │
└──────────────────┘     └──────────────────────┘     └──────────────────────┘
```

### Why two engines?

| Criteria | DuckDB | Trino |
|:---------|:-------|:------|
| **Setup** | Drop files in `data/duckdb/`, query immediately | Need to register tables in Hive Metastore first |
| **Query syntax** | `SELECT * FROM read_parquet('/data/file.parquet')` | `SELECT * FROM hive.schema.table` |
| **Federated queries** | No (single engine) | Yes — MySQL, Postgres, Kafka, Parquet in one SQL |
| **Web UI** | CLI only (docker exec) | Built-in at `http://localhost:4451/ui` |
| **JDBC/ODBC** | No native driver | Yes — connect Superset, Hop, Tableau |
| **Resource usage** | Light (~512 MB) | Moderate (~2 GB) |
| **Best for** | Quick ad-hoc Parquet analysis | Multi-source analytics & BI tool integration |

### Profiles

| Profile | Toggle | Services | Port |
|:--------|:-------|:---------|:-----|
| `duckdb` | `LDS_ENABLE_DUCKDB` | `duckdb` (official CLI image) | — (no port) |
| `trino` | `LDS_ENABLE_TRINO` | `trino`, `hive-metastore` (official images) | 4451 |

Both are OFF by default and join the `all` profile.

### DuckDB

- **Image:** Official `duckdb/duckdb` CLI image — no custom wrapper, no HTTP API
- **Usage:** `docker exec -it lds-duckdb duckdb` or `duckdb -c "SELECT ..."`
- **Data directory:** `data/duckdb/` — drop `.parquet`, `.csv`, `.json`, `.arrow` files
- **Config:** Minimal — just the Dockerfile to keep the container alive

### Trino

- **Image:** Official `trinodb/trino:latest`
- **Connectors:** Hive (Parquet), TPCH, TPCDS — add more via config
- **Hive Metastore:** Official `apache/hive:4.0.0` image (no custom build)
- **Data directory:** `data/trino/` — Parquet files registered as external tables
- **Web UI:** `http://localhost:4451/ui` — query editor, history, cluster overview
- **Config:** `configs/trino/` contains server config + catalog files

### Hive Metastore

- **Image:** Official `apache/hive:4.0.0` (no custom Dockerfile/entrypoint)
- **Startup:** command override in docker-compose.yml does postgres wait + schema init + metastore start
- **Database:** LDS Postgres (`lds_hive_metastore` database, `app` user)
- **Auto-initializes** schema on first startup (idempotent via `schematool -ifNotExists`)

---

## Port allocation

| Port | Service | Internal | Notes |
|:-----|:--------|:---------|:------|
| 4450 | DuckDB | `duckdb:4450` | REST API (httpserver extension) |
| 4451 | Trino | `trino:8080` | Web UI at `/ui` |
| 9083 | Hive Metastore | `hive-metastore:9083` | Thrift (internal only) |

---

## Files created

| File | Purpose |
|:-----|:--------|
| `configs/duckdb/Dockerfile` | Minimal wrapper around official duckdb/duckdb image |
| `configs/trino/config.properties` | Trino server configuration |
| `configs/trino/jvm.config` | JVM settings |
| `configs/trino/catalog/hive.properties` | Hive connector for Parquet |
| `configs/trino/catalog/tpch.properties` | TPCH sample data connector |
| `configs/trino/catalog/tpcds.properties` | TPCDS sample data connector |
| `configs/hive-metastore/metastore-site.xml` | Metastore config pointing to Postgres |
| `configs/hive-metastore/metastore-log4j2.properties` | Quiet logging |
| `data/duckdb/.gitkeep` | DuckDB data directory |
| `data/trino/.gitkeep` | Trino data directory |

---

## Env vars added

| Variable | Default | Description |
|:---------|:--------|:------------|
| `LDS_ENABLE_DUCKDB` | `false` | Enable DuckDB profile |
| `LDS_ENABLE_TRINO` | `false` | Enable Trino profile |
| `DUCKDB_VERSION` | `1.2.0` | DuckDB image tag |
| `DUCKDB_MEM_LIMIT` | `256m` | DuckDB container memory limit |
| `TRINO_VERSION` | `latest` | Trino image tag |
| `TRINO_HOST_PORT` | `4451` | Trino HTTP port |
| `TRINO_MEM_LIMIT` | `2g` | Trino container memory limit |
| `HIVE_METASTORE_MEM_LIMIT` | `512m` | Metastore container memory limit |

---

## Documentation updates

| File | Update |
|:-----|:-------|
| `docs/en/12-ports.md` | Added DuckDB (CLI only) + Trino (4451) ports |
| `docs/id/12-ports.md` | Added DuckDB (CLI only) + Trino (4451) ports |
| `docs/en/13-profiles.md` | Added `duckdb` and `trino` profiles table rows |
| `docs/en/15-data-tools.md` | Added "Analytical query engines" section |
| `CLAUDE.md` | Added `duckdb` and `trino` to profiles list |

---

## Usage

```bash
# Start DuckDB (for ad-hoc Parquet queries via CLI)
./lds.sh up duckdb

# Query a Parquet file via docker exec
docker exec -it lds-duckdb duckdb -c "SELECT * FROM read_parquet('/data/sales.parquet') LIMIT 10"

# Start Trino (for federated analytics)
./lds.sh up trino
# Open http://localhost:4451/ui in browser
# Query sample data:
#   SELECT * FROM tpch.tiny.orders LIMIT 10;

# Both together
./lds.sh up duckdb trino
```

---

## Future considerations

- **Trino JDBC driver** — bundle for Superset/Hop connectivity
- **Iceberg connector** — modern alternative to Hive connector for Parquet
- **Sample Parquet files** — auto-seed `data/duckdb/` and `data/trino/` on first run
- **Dashboard indicators** — live query stats from both engines
- **OWL Ontology / AI Knowledge Base** — see planning 003
