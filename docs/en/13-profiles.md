# 13 · Profiles

Every service group sits behind a Compose **profile**, so `docker compose` (and
`lds up`) only start what you ask for. This page describes each profile in
detail: what it starts, the images and ports involved, credentials, volumes, and
when you'd turn it on.

## How profiles are selected

- **Explicit:** `lds up <profile> [<profile> …]` starts exactly those, ignoring
  the toggles below. E.g. `lds up kafka` or `lds up mysql redis`.
- **Default run-set:** `lds up` with **no args** starts every profile whose
  `LDS_ENABLE_<PROFILE>=true` toggle is set in `.env`. Defaults: `proxy`, `php`,
  `mysql`, `dbx` on; everything else off. If every toggle is false →
  falls back to `all`.
- A service can belong to several profiles. `proxy` + `dns` belong to **both**
  `proxy` and `php`, so turning on `php` brings the proxy and DNS along
  automatically.

<table>
<thead>
<tr>
<th>Profile</th>
<th>`.env` toggle</th>
<th>Default</th>
<th>Services started</th>
</tr>
</thead>
<tbody>
<tr>
<td>`proxy`</td>
<td>`LDS_ENABLE_PROXY`</td>
<td>✅</td>
<td>`proxy`, `dns`</td>
</tr>
<tr>
<td>`php`</td>
<td>`LDS_ENABLE_PHP`</td>
<td>✅</td>
<td>`php`, `proxy`, `dns`</td>
</tr>
<tr>
<td>`mysql`</td>
<td>`LDS_ENABLE_MYSQL`</td>
<td>✅</td>
<td>`mysql`</td>
</tr>
<tr>
<td>`mariadb`</td>
<td>`LDS_ENABLE_MARIADB`</td>
<td>❌</td>
<td>`mariadb` — MySQL-compatible fork; also the ERPNext database</td>
</tr>
<tr>
<td>`mssql`</td>
<td>`LDS_ENABLE_MSSQL`</td>
<td>❌</td>
<td>`mssql` — SQL Server 2025 Developer (free for dev; SA password must meet policy)</td>
</tr>
<tr>
<td>`oracle`</td>
<td>`LDS_ENABLE_ORACLE`</td>
<td>❌</td>
<td>`oracle` — Oracle Database Free 23ai (no Oracle account needed via the gvenzl mirror)</td>
</tr>
<tr>
<td>`postgres`</td>
<td>`LDS_ENABLE_POSTGRES`</td>
<td>❌</td>
<td>`postgres`</td>
</tr>
<tr>
<td>`mongo`</td>
<td>`LDS_ENABLE_MONGO`</td>
<td>❌</td>
<td>`mongo`</td>
</tr>
<tr>
<td>`redis`</td>
<td>`LDS_ENABLE_REDIS`</td>
<td>❌</td>
<td>`redis`</td>
</tr>
<tr>
<td>`valkey`</td>
<td>`LDS_ENABLE_VALKEY`</td>
<td>❌</td>
<td>`valkey`</td>
</tr>
<tr>
<td>`memcached`</td>
<td>`LDS_ENABLE_MEMCACHED`</td>
<td>❌</td>
<td>`memcached`</td>
</tr>
<tr>
<td>`kafka`</td>
<td>`LDS_ENABLE_KAFKA`</td>
<td>❌</td>
<td>`kafka-controller`, `kafka-broker`, `schema-registry`, `connect-debezium`, `connect-generic`, `kafka-ui`</td>
</tr>
<tr>
<td>`phpcacheadmin`</td>
<td>`LDS_ENABLE_PHPCACHEADMIN`</td>
<td>❌</td>
<td>`phpcacheadmin`</td>
</tr>
<tr>
<td>`dbx`</td>
<td>`LDS_ENABLE_DBX`</td>
<td>✅</td>
<td>`dbx`</td>
</tr>
<tr>
<td>`soketi`</td>
<td>`LDS_ENABLE_SOKETI`</td>
<td>❌</td>
<td>`soketi`</td>
</tr>
<tr>
<td>`centrifugo`</td>
<td>`LDS_ENABLE_CENTRIFUGO`</td>
<td>❌</td>
<td>`centrifugo`</td>
</tr>
<tr>
<td>`mqtt`</td>
<td>`LDS_ENABLE_MQTT`</td>
<td>❌</td>
<td>`mosquitto`, `mqttx`</td>
</tr>
<tr>
<td>`drawdb`</td>
<td>`LDS_ENABLE_DRAWDB`</td>
<td>❌</td>
<td>`drawdb` — DB schema designer (open at `localhost:4502`)</td>
</tr>
<tr>
<td>`hop`</td>
<td>`LDS_ENABLE_HOP`</td>
<td>❌</td>
<td>`hop` — Apache Hop Web (ETL designer)</td>
</tr>
<tr>
<td>`superset`</td>
<td>`LDS_ENABLE_SUPERSET`</td>
<td>❌</td>
<td>`superset` — Apache Superset (BI)</td>
</tr>
<tr>
<td>`semgrep`</td>
<td>`LDS_ENABLE_SEMGREP`</td>
<td>❌</td>
<td>`semgrep` — SARIF viewer (`lds tools semgrep` runs the scan)</td>
</tr>
<tr>
<td>`zap`</td>
<td>`LDS_ENABLE_ZAP`</td>
<td>❌</td>
<td>`zap` — OWASP ZAP DAST scanner, browser UI at `zap.test` (:4510 UI, :4512 proxy/API)</td>
</tr>
<tr>
<td>`trivy`</td>
<td>`LDS_ENABLE_TRIVY`</td>
<td>❌</td>
<td>`trivy` — report viewer at `trivy.test` (`lds tools trivy` runs the scan)</td>
</tr>
<tr>
<td>`crg`</td>
<td>`LDS_ENABLE_CRG`</td>
<td>❌</td>
<td>`crg` — code-review-graph viewer at `crg.test` (`lds tools crg &lt;path&gt;` runs the scan)</td>
</tr>
<tr>
<td>`analytics`</td>
<td>`LDS_ENABLE_ANALYTICS`</td>
<td>❌</td>
<td>`analytics-api`, `analytics-ui` — Nuxt/Vue reactive analytics</td>
</tr>
<tr>
<td>`vaultwarden`</td>
<td>`LDS_ENABLE_VAULTWARDEN`</td>
<td>❌</td>
<td>`vaultwarden` — password manager</td>
</tr>
<tr>
<td>`mail`</td>
<td>`LDS_ENABLE_MAIL`</td>
<td>❌</td>
<td>`mailpit` — local SMTP sink + web inbox</td>
</tr>
<tr>
<td>`penpot`</td>
<td>`LDS_ENABLE_PENPOT`</td>
<td>❌</td>
<td>`penpot-frontend`, `penpot-backend`, `penpot-exporter` — collaborative design</td>
</tr>
<tr>
<td>`instatic`</td>
<td>`LDS_ENABLE_INSTATIC`</td>
<td>❌</td>
<td>`instatic` — self-hosted visual CMS / website builder at `instatic.test`</td>
</tr>
<tr>
<td>`duckdb`</td>
<td>`LDS_ENABLE_DUCKDB`</td>
<td>❌</td>
<td>`duckdb` — embedded OLAP engine (CLI only, exec into container)</td>
</tr>
<tr>
<td>`trino`</td>
<td>`LDS_ENABLE_TRINO`</td>
<td>❌</td>
<td>`trino`, `hive-metastore` — distributed SQL query engine (official images)</td>
</tr>
<tr>
<td>`tasks`</td>
<td>`LDS_ENABLE_TASKS`</td>
<td>❌</td>
<td>`tasks-api`, `tasks-ui` — Angular project management</td>
</tr>
<tr>
<td>`wiki`</td>
<td>`LDS_ENABLE_WIKI`</td>
<td>❌</td>
<td>`wiki-api`, `wiki-ui` — Next.js documentation</td>
</tr>
<tr>
<td>`openwa`</td>
<td>`LDS_ENABLE_OPENWA`</td>
<td>❌</td>
<td>`openwa` — WhatsApp API server (reuses shared `postgres` + `redis`)</td>
</tr>
<tr>
<td>`rustfs`</td>
<td>`LDS_ENABLE_RUSTFS`</td>
<td>❌</td>
<td>`rustfs` — self-hosted file sharing (API + console)</td>
</tr>
<tr>
<td>`headlessx`</td>
<td>`LDS_ENABLE_HEADLESSX`</td>
<td>❌</td>
<td>`headlessx-api`, `headlessx-worker`, `headlessx-web`, `headlessx-html-to-md`, `headlessx-yt-engine` — undetected browser automation (built from `data/headlessx`)</td>
</tr>
<tr>
<td>`playwright`</td>
<td>`LDS_ENABLE_PLAYWRIGHT`</td>
<td>❌</td>
<td>`playwright`, `playwright-report` — End-To-End test runner (official image) + HTML report viewer</td>
</tr>
<tr>
<td>`erpnext`</td>
<td>`LDS_ENABLE_ERPNEXT`</td>
<td>❌</td>
<td>`erpnext-*` — full ERP suite on Frappe, DB on the shared `postgres` (or `mariadb` via `ERPNEXT_DB_TYPE`); **heavy** (~3-6 GB RAM, multi-GB pulls)</td>
</tr>
<tr>
<td>`all`</td>
<td>—</td>
<td>—</td>
<td>every service above</td>
</tr>
</tbody>
</table>

> **Custom apps** (`analytics`, `tasks`, `wiki`), **data tools** (`drawdb`, `hop`,
> `superset`, `semgrep`, `zap`, `trivy`, `crg`, `vaultwarden`, `mail`, `penpot`,
> `instatic`, `openwa`, `rustfs`) and the **automation/testing profiles**
> (`headlessx`, `playwright`) get their own page —
> see [15 · Dashboard & data tools](15-data-tools.md). The `http://localhost`
> control panel links them all with live status.

---

## `proxy` — edge reverse proxy + DNS

**Starts:** `proxy` + `dns`. **Toggle:** `LDS_ENABLE_PROXY`. **On by default.**

The entry point for every project's `<name>.test` URL — listed first because
almost everything else routes through it. It's the proxy + DNS **on its own**,
without the PHP container, so it's also the right profile to enable for **non-PHP**
apps (Go, Rust, Node, Java) that need `<name>.test` URLs without a PHP runtime up.

- **`proxy`** — `nginxproxy/nginx-proxy` on host port `${WEB_HOST_PORT}` (default
  `80`). Watches the Docker socket and routes `<name>.test` to any container that
  sets `VIRTUAL_HOST` (+ `VIRTUAL_PORT`). This is how every language's app gets a
  hostname.
- **`dns`** — `dnsmasq` (locally built image) on host port `${DNS_HOST_PORT}`
  (default `53`, udp + tcp). Resolves `*.test` → `127.0.0.1` so new project
  folders/containers are instantly reachable with no hosts-file edits.

> `proxy` + `dns` are **shared** with the `php` profile, so turning on `php`
> already brings them up — the `proxy` toggle on its own matters when `php` is
> off. The `.test` TLD is referenced in **both** `configs/nginx/default.conf` and
> `configs/dns/dnsmasq.conf`; change it in both to use a different suffix.
>
> **HTTP by default:** the proxy serves plain `http://`. For `https://*.test`,
> enable the opt-in HTTPS overlay (`lds certs` + `LDS_ENABLE_HTTPS=true`) — see
> the TLS note at the end of this page.

## `php` — Devilbox-style PHP multi-project hosting

**Starts:** `php` + `proxy` + `dns`. **Toggle:** `LDS_ENABLE_PHP`. **On by default.**

The `php` service runs the `lds/php:${PHP_VERSION}` base image — one container
running `supervisord` → `php-fpm` + `nginx`. It's a **mass virtual host**: every
folder under `${PHP_PROJECTS_PATH}` is automatically served at `<folder>.test`,
with the docroot auto-detected in the order `public/` > `htdocs/` > the folder
root. No per-project config — drop a folder in and it's live.

- **Image:** `lds/php:${PHP_VERSION}` (default `8.4`) — built once via
  `lds build-bases`. php-fpm + nginx + composer + supervisor + supercronic baked in.
- **Mount:** `${PHP_PROJECTS_PATH}` → `/var/www` (the live mass-vhost root).
- **supervisord toggles:** `ENABLE_PHP`, `ENABLE_NGINX` (both on here),
  `ENABLE_CRON` (off).
- Bundled `proxy` + `dns` (see above) give the `.test` hostnames. The php
  container is the **catch-all** vhost (`localhost` + regex `*.test`), so any
  request not claimed by a more specific `VIRTUAL_HOST` lands here.

**Use it when** you develop PHP apps (plain, Laravel, Symfony, CodeIgniter, etc.).
See [06](06-php-multiproject.md).

## `mysql` — MySQL 8.4

**Starts:** `mysql`. **Toggle:** `LDS_ENABLE_MYSQL`. **On by default.**

- **Image:** `mysql:${MYSQL_VERSION}` (default `8.4`).
- **Port:** host `${MYSQL_HOST_PORT}` (default `4400`) → container `3306`.
- **Credentials:** root `${MYSQL_ROOT_PASSWORD}` (default `root`); app user
  `${MYSQL_USER}`/`${MYSQL_PASSWORD}` (default `app`/`app`) on DB
  `${MYSQL_DATABASE}` (default `app`).
- **CDC-ready:** started with `--log-bin`, `--binlog-format=ROW`,
  `--binlog-row-image=FULL`, `--gtid-mode=ON` — Debezium works out of the box.
- **Init:** SQL in `configs/mysql/init/` runs on first boot.
- **Volume:** `mysql-data` (persists across restarts; wiped by `lds down -v`).

## `mariadb` — MariaDB 11.8

**Starts:** `mariadb`. **Toggle:** `LDS_ENABLE_MARIADB`. **Off by default.**

Drop-in MySQL-compatible fork (DHI hardened image). Runs with **utf8mb4 server
defaults** (`--character-set-server=utf8mb4
--collation-server=utf8mb4_unicode_ci --skip-character-set-client-handshake`) —
which is exactly what ERPNext needs, so **ERPNext reuses this shared instance**
(the `erpnext` profile pulls `mariadb` in automatically).

- **Image:** `mariadb:${MARIADB_VERSION}` (default `11.8-debian13`).
- **Port:** host `${MARIADB_HOST_PORT}` (default `4406`) → container `3306`.
- **Credentials:** root `${MARIADB_ROOT_PASSWORD}` (default `root`); app user
  `${MARIADB_USER}`/`${MARIADB_PASSWORD}` (default `app`/`app`) on DB
  `${MARIADB_DATABASE}` (default `app`).
- **Volume:** `mariadb-data`.

## `mssql` — Microsoft SQL Server 2025 (Developer)

**Starts:** `mssql`. **Toggle:** `LDS_ENABLE_MSSQL`. **Off by default.**

Free Developer edition for development/testing (`ACCEPT_EULA=Y` is the license
consent). Two hard requirements: **`MSSQL_SA_PASSWORD` must satisfy the SQL
Server password policy** (8+ chars, 3 of 4: upper/lower/digit/symbol) or the
server exits on boot, and **`MSSQL_MEM_LIMIT` must stay ≥ 2g**.

- **Image:** `mcr.microsoft.com/mssql/server:${MSSQL_VERSION}` (default
  `2025-latest`, ~1.5 GB; Microsoft's scheme is `<year>-latest` — the previous
  major is still available as `2022-latest`).
- **Port:** host `${MSSQL_HOST_PORT}` (default `4407`) → container `1433`.
- **Credentials:** `sa` / `${MSSQL_SA_PASSWORD}` (default `Lds-dev-2024!`).
- **Volume:** `mssql-data`. First boot runs setup before accepting connections.

## `oracle` — Oracle Database Free 23ai

**Starts:** `oracle`. **Toggle:** `LDS_ENABLE_ORACLE`. **Off by default.**

Free developer license via the **`gvenzl/oracle-free`** mirror — no Oracle
account/login needed (the official `container-registry.oracle.com` image
requires one). `ORACLE_PASSWORD` is **required** and sets `SYS`/`SYSTEM`;
`ORACLE_DATABASE` (default `FREE`) creates a PDB of that name.

- **Image:** `gvenzl/oracle-free:${ORACLE_VERSION}` (default `23.26.2-slim`, ~3 GB;
  pinned to the latest supported 23.x — use `23-slim` to float the major).
- **Ports:** host `${ORACLE_HOST_PORT}` (default `4408`) → `1521` (DB); EM
  Express web console at `https://localhost:4409/em`.
- **Credentials:** `SYS`/`SYSTEM` with `${ORACLE_PASSWORD}` (default
  `Oracle-dev-2024!`); app user `${ORACLE_USER}` (default `app`).
- **Volume:** `oracle-data`. First boot creates the DB (~1-2 min, several GB
  disk); the container runs as uid 54321 (chown `oracle-data` on Linux if
  volume writes fail).

## `postgres` — PostgreSQL 16

**Starts:** `postgres`. **Toggle:** `LDS_ENABLE_POSTGRES`. **Off by default.**

- **Image:** `postgres:${POSTGRES_VERSION}` (default `16-alpine`).
- **Port:** host `${POSTGRES_HOST_PORT}` (default `4401`) → container `5432`.
- **Credentials:** `${POSTGRES_USER}`/`${POSTGRES_PASSWORD}` on DB
  `${POSTGRES_DB}` (all default `app`).
- **CDC-ready:** runs with `wal_level=logical`, `max_wal_senders=10`,
  `max_replication_slots=10` for Debezium logical replication.
- **Init:** SQL in `configs/postgres/init/` runs on first boot.
- **Volume:** `postgres-data`.

## `mongo` — MongoDB 7 (single-node replica set)

**Starts:** `mongo`. **Toggle:** `LDS_ENABLE_MONGO`. **Off by default.**

- **Image:** `mongo:${MONGO_VERSION}` (default `7`).
- **Port:** host `${MONGO_HOST_PORT}` (default `4402`) → container `27017`.
- **Replica set:** runs as a single-node replica set **`rs0`** with **keyfile
  auth** — required for change streams / Debezium CDC. The keyfile is
  auto-generated into the `mongo-config` volume (no committed secret).
- **Bootstrap:** the replica set is initiated and the `root` / `app` users are
  created by `scripts/run/mongo-init.*` (auto-run by `lds up` for `mongo`/`all`;
  idempotent) — **not** by `MONGO_INITDB_*`, which can't create users on a
  replSet-enabled server.
- **Init:** `*.js` / `*.sh` in `configs/mongo/init/` run on first boot.
- **Volumes:** `mongo-data`, `mongo-config`.

## `redis` — Redis 7

**Starts:** `redis`. **Toggle:** `LDS_ENABLE_REDIS`. **Off by default.**

- **Image:** `redis:${REDIS_VERSION}` (default `7-alpine`).
- **Port:** host `${REDIS_HOST_PORT}` (default `4403`) → container `6379`.
- **Config:** `configs/redis/redis.conf` (mounted read-only).
- **Volume:** `redis-data`.
- Inspect it visually with the `phpcacheadmin` profile.

## `valkey` — Valkey (Redis-compatible)

**Starts:** `valkey`. **Toggle:** `LDS_ENABLE_VALKEY`. **Off by default.**

- **Image:** `valkey/valkey:${VALKEY_VERSION}`.
- **Port:** host `${VALKEY_HOST_PORT}` (default `4405`) → container `6379`.
- **Storage:** appendonly persistence on volume `valkey-data`.
- Redis protocol compatible; use it as a drop-in cache/data store.

## `memcached` — Memcached 1.6

**Starts:** `memcached`. **Toggle:** `LDS_ENABLE_MEMCACHED`. **Off by default.**

- **Image:** `memcached:${MEMCACHED_VERSION}` (default `1.6-alpine`).
- **Port:** host `${MEMCACHED_HOST_PORT}` (default `4404`) → container `11211`.
- **Memory cap:** `${MEMCACHED_MEMORY}` MB (default `64`).
- **No volume** — purely in-memory; data is gone on restart by design.
- Inspect it via the `phpcacheadmin` profile.

## `kafka` — full Kafka stack (KRaft + Debezium CDC)

**Starts:** `kafka-controller`, `kafka-broker`, `schema-registry`,
`connect-debezium`, `connect-generic`, `kafka-ui`. **Toggle:** `LDS_ENABLE_KAFKA`.
**Off by default.** See [09](09-kafka-debezium.md) for the full walkthrough.

- **KRaft mode** (no ZooKeeper): a dedicated **controller** (node 1) and
  **broker** (node 2), image `apache/kafka:${KAFKA_VERSION}`. Set
  `KAFKA_CLUSTER_ID` *before* first start — changing it later means wiping the
  `kafka-*-data` volumes.
  - Broker bootstrap: host `${KAFKA_HOST_PORT}` (default `4420`) → `29092`
    (EXTERNAL); in-network clients use `kafka-broker:9092` (INTERNAL).
- **`schema-registry`** — **Apicurio Registry** (Apache 2.0, in-memory) on host
  `${SCHEMA_REGISTRY_HOST_PORT}` (default `4421`). Confluent-compatible API at
  `/apis/ccompat/v7`. Dev only: schemas reset on restart (auto re-registered).
- **`connect-debezium`** — Kafka Connect on the **Debezium** image (MySQL +
  Postgres CDC source connectors bundled). REST on `${CONNECT_HOST_PORT}` (default
  `4423`). Connector JSON lives in `configs/kafka/connect/`.
- **`connect-generic`** — Kafka Connect on the **vanilla apache/kafka** image
  (same runtime, **no** bundled connectors). Drop plugin JARs into
  `configs/kafka/connect-generic/plugins/`. REST on `${CONNECT_GENERIC_HOST_PORT}`
  (default `4422`). Uses its own group + state topics so it won't clash with the
  Debezium worker.
- **`kafka-ui`** — kafbat Kafka UI on host `${KAFKA_UI_HOST_PORT}` (default
  `4424`), pre-wired to the broker, schema registry, and both Connect workers.
- **Topics:** provisioned from `${KAFKA_TOPICS}` by `scripts/run/kafka-topics.*`
  (auto-run by `lds up` for the kafka profile, or manually via `lds kafka-topics`).
- **Volumes:** `kafka-controller-data`, `kafka-broker-data`.

## Admin UIs — `phpcacheadmin` and `dbx`

The two web admin UIs each have **their own profile** so you can turn them on
independently (there is no `tools` umbrella). Both are reachable via the proxy
(`*.test`) **and** a direct host port, and both only show data when the matching
data profile is also up.

> For the `.test` URLs you also need `proxy` (or `php`) running; for actual data,
> run the matching `mysql` / `postgres` / `redis` / `valkey` / `memcached` profile.

### `phpcacheadmin` — Redis + Valkey + Memcached browser

**Starts:** `phpcacheadmin`. **Toggle:** `LDS_ENABLE_PHPCACHEADMIN`. **Off by
default** (turn it on when you run `redis`/`memcached`).

- Redis + Valkey + Memcached + OPcache/APCu browser. `${CACHE_ADMIN_HOST}` (default
  `cache.test`) / host `${CACHE_ADMIN_HOST_PORT}` (default `4500`).
- Pre-pointed at the `redis`, `valkey`, and `memcached` services — start one (or more) to
  see data. No volume (stateless UI).

### `dbx` — web DB client

**Starts:** `dbx`. **Toggle:** `LDS_ENABLE_DBX`. **On by default.**

- Web DB client for **100+ engines** (MySQL, MariaDB, Postgres, MongoDB, SQL
  Server, Oracle, Redis, DuckDB, …), with a built-in SQL editor, ER diagrams and
  an MCP server. `${DB_ADMIN_HOST}` (default `db.test`) / host
  `${DB_ADMIN_HOST_PORT}` (default `4501`).
- **Open by default** — `DBX_DISABLE_PASSWORD=1` means no login wall (set it to
  `0` + `DBX_PASSWORD=…` in `.env` to gate the UI). Add/edit/delete connections
  freely.
- The stack's MySQL + MariaDB + Postgres + MongoDB + SQL Server + Oracle are
  auto-listed via `scripts/run/dbx-seed.*` (auto-run by `lds up` for the
  `dbx`/`all` profile; it POSTs to DBX's Web API **after** the container is up,
  and skips when connections already exist).
- Connections live in `dbx.db` inside the bind-mounted `data/dbx/` directory
  (together with `.dbx/secret.key` — back them up as a pair).
- Image `t8y2/dbx` (Apache-2.0, upstream — not a DHI image), pinned by
  `DBX_VERSION`, mem-capped by `DBX_MEM_LIMIT` (default `768m`).

## Realtime / pub-sub brokers — `soketi`, `centrifugo`, `mqtt`

All three are **off by default**, **stateless** (no data volume → no disk creep),
and **mem/cpu-capped**. They speak **different** client protocols and are **not**
interchangeable — pick the one whose client protocol matches your app. One broker
serves unlimited channels/topics; you never run a second instance per channel.

### `soketi` — Pusher protocol

**Toggle:** `LDS_ENABLE_SOKETI`. Headless (no UI).

- **Image:** `quay.io/soketi/soketi:${SOKETI_VERSION}`. Port host
  `${SOKETI_HOST_PORT}` (default `4440`) → `6001`; also `${SOKETI_HOST}`
  (default `ws.test`) via the proxy.
- Drop-in for **Laravel broadcasting** (`BROADCAST_DRIVER=pusher`/reverb) +
  **Laravel Echo** / `pusher-js`. App credentials: `${SOKETI_APP_ID}` /
  `${SOKETI_APP_KEY}` / `${SOKETI_APP_SECRET}` (dev defaults — override for
  anything shared).
- Caps: `${SOKETI_MEM_LIMIT}` (default `256m`), `${SOKETI_CPUS}` (default `0.50`).

### `centrifugo` — raw WebSocket channels + admin UI

**Toggle:** `LDS_ENABLE_CENTRIFUGO`.

- **Image:** `centrifugo/centrifugo:${CENTRIFUGO_VERSION}`. Port host
  `${CENTRIFUGO_HOST_PORT}` (default `4441`) → `8000`; admin UI at
  `${CENTRIFUGO_HOST}` (default `centrifugo.test`).
- Clients use the **Centrifuge JS SDK** (not Echo). Runs in dev **insecure** mode
  (`--admin_insecure --client_insecure --api_insecure`) so you can pub/sub without
  minting JWTs — flip the flags off for auth. Keys: `${CENTRIFUGO_API_KEY}`,
  `${CENTRIFUGO_TOKEN_HMAC_SECRET_KEY}`, admin `${CENTRIFUGO_ADMIN_PASSWORD}`.
- Caps: `${CENTRIFUGO_MEM_LIMIT}` (default `256m`), `${CENTRIFUGO_CPUS}` (`0.50`).

### `mqtt` — Mosquitto broker + MQTTX web client

**Toggle:** `LDS_ENABLE_MQTT`. Lightweight profile: broker + browser client.

- **Broker image:** `eclipse-mosquitto:${MOSQUITTO_VERSION}`. Ports:
  `${MQTT_HOST_PORT}` (default `4442`) → `1883` (native MQTT),
  `${MQTT_WS_HOST_PORT}` (default `4443`) → `9001` (MQTT-over-WebSocket, path `/`).
- **Web client image:** `emqx/mqttx-web:${MQTTX_VERSION}` at
  `${MQTT_HOST}` (default `mqtt.test`) / `${MQTTX_HOST_PORT}` (default `4444`).
- Clients use an **MQTT library** (MQTT.js / Paho in the browser, native MQTT for
  backends). `mqttx` is a client UI (publish/subscribe), not a broker admin dashboard.
- Caps: `${MOSQUITTO_MEM_LIMIT}` (default `128m`), `${MQTTX_MEM_LIMIT}` (default `128m`).




## `vaultwarden` — password manager

**Starts:** `vaultwarden`. **Toggle:** `LDS_ENABLE_VAULTWARDEN`. **Off by default.**

- **Image:** `vaultwarden/server:${VAULTWARDEN_VERSION}`.
- **UI/API:** `${VAULTWARDEN_HOST}` (default `vaultwarden.test`) and host port
  `${VAULTWARDEN_HOST_PORT}` (default `4506`).
- **Storage:** persistent sqlite-backed volume (`vaultwarden-data`).
- **Defaults:** signups off by default (`VAULTWARDEN_SIGNUPS_ALLOWED=false`);
  admin panel gated by `VAULTWARDEN_ADMIN_TOKEN`.

## `mail` — Mailpit (local SMTP + inbox)

**Starts:** `mailpit`. **Toggle:** `LDS_ENABLE_MAIL`. **Off by default.**

- **Image:** `axllent/mailpit:${MAILPIT_VERSION}`.
- **Web UI:** `${MAIL_HOST}` (default `mail.test`) / `${MAIL_HOST_PORT}` (default `4513`).
- **SMTP:** host `${MAIL_SMTP_HOST_PORT}` (default `4514`) → container `1025`.
- **Storage:** persisted in `data/mailpit/` (`MP_DATA_FILE`).

## `penpot` — collaborative design tool

**Starts:** `penpot-frontend`, `penpot-backend`, `penpot-exporter`. **Toggle:** `LDS_ENABLE_PENPOT`. **Off by default.**

- **UI:** `${PENPOT_HOST}` (default `penpot.test`) / `${PENPOT_HOST_PORT}` (default `4518`).
- **Dependencies:** reuses shared `postgres` and `valkey` (included by the `penpot` profile).
- **DB defaults:** reuses `${PENPOT_POSTGRES_DB:-app}` with `${PENPOT_POSTGRES_USER:-app}`.
- **Assets:** persisted on host at `data/penpot/assets`.

## `openwa` — WhatsApp API gateway

**Starts:** `openwa`. **Toggle:** `LDS_ENABLE_OPENWA`. **Off by default.**

Self-hosted WhatsApp API gateway (the `rmyndharis/OpenWA` fork) — NestJS
backend + React dashboard, multi-session management, webhooks, pluggable
WhatsApp engines (whatsapp-web.js / Baileys).

- **Image:** `ghcr.io/rmyndharis/openwa:${OPENWA_VERSION}` (default `latest`).
- **UI/API:** `${OPENWA_HOST}` (default `openwa.test`) / host port
  `${OPENWA_HOST_PORT}` (default `4507`) → container `2785`.
- **Dependencies:** reuses shared `postgres` (dedicated `lds_openwa` DB,
  auto-created via `POSTGRES_INIT_SPECS`) and `redis` (optional,
  `OPENWA_REDIS_ENABLED` off by default).
- **Master key:** `${OPENWA_MASTER_KEY}` (dev default in `.env` — change it
  before exposing the stack).
- **Volume:** `openwa-data` (`/app/data` — sessions, media).

## `rustfs` — file sharing (S3-compatible)

**Starts:** `rustfs`. **Toggle:** `LDS_ENABLE_RUSTFS`. **Off by default.**

Self-hosted S3-compatible object storage server with a web console — the
open-source self-hosted file-sharing alternative to services like Tusky.

- **Image:** `rustfs/rustfs:${RUSTFS_VERSION}` (default `latest`).
- **API:** host port `${RUSTFS_API_PORT}` (default `4508`) → container `9000`
  (S3 API).
- **Console:** `${RUSTFS_HOST}` (default `rustfs.test`) / host port
  `${RUSTFS_CONSOLE_PORT}` (default `4509`) → container `9001`.
- **Credentials:** `${RUSTFS_ACCESS_KEY}` / `${RUSTFS_SECRET_KEY}` (dev defaults
  in `.env`); a default bucket `${RUSTFS_BUCKET}` (default `lds-data`) is
  created at first boot.
- **Volume:** `rustfs-data`.

## `headlessx` — undetected browser automation / scraping

**Starts:** `headlessx-api`, `headlessx-worker`, `headlessx-web`, `headlessx-html-to-md`,
`headlessx-yt-engine`. **Toggle:** `LDS_ENABLE_HEADLESSX`. **Off by default.** Built from
source — there is no published image.

- **What it is:** self-hosted scraping platform — Next.js dashboard, Express API +
  queue worker, remote MCP endpoint (`/mcp`), powered by a patched Firefox
  (Camoufox) browser runtime.
- **Source:** a local git checkout of `https://github.com/saifyxpro/HeadlessX` at
  `${HEADLESSX_REPO_PATH}` (default `data/headlessx`). `lds up headlessx` (or
  `lds headlessx init`) clones it on first run and fast-forwards it afterwards;
  `lds headlessx update` refreshes manually.
- **Dependencies:** reuses shared `postgres` (dedicated `lds_headlessx` DB,
  auto-created via `POSTGRES_INIT_SPECS`) and `redis` (logical DB
  `${HEADLESSX_REDIS_DB}`, default `4`) — both auto-started by the `headlessx`
  profile.
- **UI/API:** web at `${HEADLESSX_HOST}` (default `headlessx.test`) / host port
  `${HEADLESSX_WEB_HOST_PORT}` (default `4515`); API + MCP at
  `${HEADLESSX_API_HOST}` (default `headlessx-api.test`) / host port
  `${HEADLESSX_API_HOST_PORT}` (default `4516`). The dashboard proxies `/api/*`
  to the API internally, so the browser only ever talks to `headlessx.test`.
- **Keys:** `HEADLESSX_DASHBOARD_INTERNAL_API_KEY` +
  `HEADLESSX_CREDENTIAL_ENCRYPTION_KEY` (dev defaults in `.env` — override
  before exposing the stack).
- **First Google AI Search run:** open the Google AI Search playground, click
  **Build Cookies**, browse once, then **Stop Browser** — the session is saved
  into the `headlessx-browser-profile` volume and reused.
- **Heavy:** the first `lds up headlessx` builds four images (pnpm/nx install +
  browser bundle fetch) — expect a long first build and several GB of RAM once
  running.

## `playwright` — End-To-End testing

**Starts:** `playwright` (runner) + `playwright-report` (viewer). **Toggle:**
`LDS_ENABLE_PLAYWRIGHT`. **Off by default.**

- **Runner:** official `mcr.microsoft.com/playwright:${PLAYWRIGHT_VERSION}` image
  (Node + Chromium/Firefox/WebKit pre-installed). It's a long-running container
  joined to the **in-network DNS** (like ZAP) so its browsers resolve `*.test`
  through the proxy and can test `http://<app>.test` services exactly like a
  host browser.
- **Projects:** test projects live in `data/playwright/projects/<name>`
  (scaffold with `lds playwright init <name> [url]`, which pins
  `@playwright/test` to the image's Playwright version).- **Run:** `lds playwright run <name> [playwright args…]` execs `npx playwright
test` in the warm container (auto-`npm install` on first run). Record tests
  with `lds playwright codegen <url>`, poke around with `lds playwright shell`.
- **UI Mode:** `lds playwright ui <name>` serves Playwright's interactive UI
  (watch mode, time-travel debugging, run individual tests) on host port
  `${PLAYWRIGHT_UI_HOST_PORT}` (default `4527`) — open it in your browser. The
  UI panel is a web app in your browser; the tests themselves still execute in
  the container's headless browsers.
- **Reports:** each run writes an HTML report to
  `data/playwright/reports/<name>/`, served by the viewer at
  `${PLAYWRIGHT_REPORT_HOST}` (default `playwright.test`) / host port
  `${PLAYWRIGHT_REPORT_HOST_PORT}` (default `4526`).
- **Heavy:** the runner image bundles all three browsers (~1.5 GB) — the first
  `lds up playwright` / `lds playwright run` pull takes a while.

## `all` — everything

**Toggle:** none — pass it explicitly with `lds up all`, or it's the automatic
fallback when every `LDS_ENABLE_*` toggle is `false`. Every service above joins
the `all` profile, so this starts the entire stack at once. Heavy — only use it
when you really want all of it (or for a quick smoke test).

---

## TLS / certificates — HTTP by default, HTTPS opt-in

**Out of the box there are no certificates** — the edge `proxy` and the `php`
nginx listen on port `80` only, so every `<name>.test`, `cache.test`, `db.test`,
`mqtt.test`, etc. is served over plain **`http://`**. This is the right default
for local dev: zero cert setup, no browser trust prompts, and tools like
Debezium/Connect talk to the brokers and DBs directly over the internal network
anyway.

When you do need HTTPS locally (testing `Secure` cookies, HSTS, service workers,
or an SDK that refuses non-TLS), turn on the **HTTPS overlay** — a single
wildcard cert for `*.test` terminated at the proxy on port `443`:

1. **Mint the dev cert** (once): `lds certs`. It prefers
   [`mkcert`](https://github.com/FiloSottile/mkcert) (installs a trusted local CA
   → no browser warnings); if mkcert isn't installed it falls back to a
   self-signed `openssl` cert (works, but the browser warns until you trust it).
   The cert lands in `configs/proxy/certs/test.{crt,key}` (git-ignored — it
   holds a private key) and its SANs cover `*.test`, `test`, and `localhost`.
   It's named after the TLD so nginx-proxy auto-matches every `<name>.test`
   vhost to it; the php container sets `CERT_NAME=test` so `localhost` and the
   PHP-project catch-all use it too.
2. **Enable the toggle** in `.env`: `LDS_ENABLE_HTTPS=true`.
3. **Restart:** `lds up`. When HTTPS is on *and* a `proxy`/`php` profile is in
   the run-set, `lds up` layers `docker-compose.https.yml` onto the base file —
   adding the `443` listener (`${WEB_HTTPS_PORT}`), the certs mount, and
   `HTTPS_METHOD` — and auto-mints the cert if it's missing. Now
   `https://<name>.test`, `https://cache.test`, etc. all work.

`HTTPS_METHOD=noredirect` (the default) keeps **both** http and https working;
set `HTTPS_METHOD=redirect` in `.env` to force http → https. It's a true overlay:
with `LDS_ENABLE_HTTPS=false` the base stack is byte-for-byte the HTTP-only setup,
so nothing changes until you opt in.

### Troubleshooting `ERR_CERT_AUTHORITY_INVALID`

- **Regenerated the cert but the browser still rejects it?** nginx re-reads cert
  files only on reload — changing the bind-mounted file does **not** restart the
  proxy, so it keeps serving the *old* cert. `lds certs` now reloads `lds-proxy`
  automatically; if you swapped the file by hand, run `lds certs --force` (or
  `docker exec lds-proxy nginx -s reload`). Confirm what's actually served with:
  `echo | openssl s_client -connect 127.0.0.1:443 -servername app.test | openssl x509 -noout -issuer`
  — the issuer should read `mkcert development CA`, not `O=local-dev-stack`
  (the latter is the untrusted self-signed fallback).
- **Using the self-signed fallback** (mkcert wasn't installed when the cert was
  minted) → there is no trusted CA, so every browser warns. Install
  [`mkcert`](https://github.com/FiloSottile/mkcert), then `lds certs --force`.
- **mkcert cert but still untrusted?** The local CA must be in the trust store —
  `mkcert -install` does this (re-run it if needed). Then **fully restart the
  browser** (Chrome/Edge cache cert errors per session; a hard refresh isn't
  enough). **Firefox** keeps its *own* trust store — mkcert only adds the CA to
  it when NSS tools are present, otherwise trust the CA in Firefox manually.

See [12 · Ports](12-ports.md) for the full host-port map, and
[09 · Kafka + Debezium](09-kafka-debezium.md) for the Kafka stack in depth.
