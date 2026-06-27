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
  `mysql`, `dbgate` on; everything else off. If every toggle is false →
  falls back to `all`.
- A service can belong to several profiles. `proxy` + `dns` belong to **both**
  `proxy` and `php`, so turning on `php` brings the proxy and DNS along
  automatically.

| Profile      | `.env` toggle           | Default | Services started                                                   |
|--------------|-------------------------|:-------:|--------------------------------------------------------------------|
| `proxy`      | `LDS_ENABLE_PROXY`      |   ✅    | `proxy`, `dns`                                                     |
| `php`        | `LDS_ENABLE_PHP`        |   ✅    | `php`, `proxy`, `dns`                                               |
| `mysql`      | `LDS_ENABLE_MYSQL`      |   ✅    | `mysql`                                                            |
| `postgres`   | `LDS_ENABLE_POSTGRES`   |   ❌    | `postgres`                                                        |
| `mongo`      | `LDS_ENABLE_MONGO`      |   ❌    | `mongo`                                                           |
| `redis`      | `LDS_ENABLE_REDIS`      |   ❌    | `redis`                                                          |
| `memcached`  | `LDS_ENABLE_MEMCACHED`  |   ❌    | `memcached`                                                       |
| `kafka`      | `LDS_ENABLE_KAFKA`      |   ❌    | `kafka-controller`, `kafka-broker`, `schema-registry`, `connect-debezium`, `connect-generic`, `kafka-ui` |
| `phpcacheadmin` | `LDS_ENABLE_PHPCACHEADMIN` | ❌ | `phpcacheadmin`                                              |
| `dbgate`     | `LDS_ENABLE_DBGATE`     |   ✅    | `dbgate`                                                        |
| `soketi`     | `LDS_ENABLE_SOKETI`     |   ❌    | `soketi`                                                         |
| `centrifugo` | `LDS_ENABLE_CENTRIFUGO` |   ❌    | `centrifugo`                                                     |
| `emqx`       | `LDS_ENABLE_EMQX`       |   ❌    | `emqx`                                                           |
| `drawdb`     | `LDS_ENABLE_DRAWDB`     |   ❌    | `drawdb` — DB schema designer (open at `localhost:4423`)        |
| `hop`        | `LDS_ENABLE_HOP`        |   ❌    | `hop` — Apache Hop Web (ETL designer)                           |
| `superset`   | `LDS_ENABLE_SUPERSET`   |   ❌    | `superset` — Apache Superset (BI)                               |
| `semgrep`    | `LDS_ENABLE_SEMGREP`    |   ❌    | `semgrep` — SARIF viewer (`lds tools semgrep` runs the scan)    |
| `all`        | —                       |   —     | every service above                                              |

> **Data tools** (`drawdb`, `hop`, `superset`, `semgrep`) get their own page —
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
  - Broker bootstrap: host `${KAFKA_HOST_PORT}` (default `4410`) → `29092`
    (EXTERNAL); in-network clients use `kafka-broker:9092` (INTERNAL).
- **`schema-registry`** — **Apicurio Registry** (Apache 2.0, in-memory) on host
  `${SCHEMA_REGISTRY_HOST_PORT}` (default `4411`). Confluent-compatible API at
  `/apis/ccompat/v7`. Dev only: schemas reset on restart (auto re-registered).
- **`connect-debezium`** — Kafka Connect on the **Debezium** image (MySQL +
  Postgres CDC source connectors bundled). REST on `${CONNECT_HOST_PORT}` (default
  `4413`). Connector JSON lives in `configs/kafka/connect/`.
- **`connect-generic`** — Kafka Connect on the **vanilla apache/kafka** image
  (same runtime, **no** bundled connectors). Drop plugin JARs into
  `configs/kafka/connect-generic/plugins/`. REST on `${CONNECT_GENERIC_HOST_PORT}`
  (default `4412`). Uses its own group + state topics so it won't clash with the
  Debezium worker.
- **`kafka-ui`** — kafbat Kafka UI on host `${KAFKA_UI_HOST_PORT}` (default
  `4420`), pre-wired to the broker, schema registry, and both Connect workers.
- **Topics:** provisioned from `${KAFKA_TOPICS}` by `scripts/run/kafka-topics.*`
  (auto-run by `lds up` for the kafka profile, or manually via `lds kafka-topics`).
- **Volumes:** `kafka-controller-data`, `kafka-broker-data`.

## Admin UIs — `phpcacheadmin` and `dbgate`

The two web admin UIs each have **their own profile** so you can turn them on
independently (there is no `tools` umbrella). Both are reachable via the proxy
(`*.test`) **and** a direct host port, and both only show data when the matching
data profile is also up.

> For the `.test` URLs you also need `proxy` (or `php`) running; for actual data,
> run the matching `mysql` / `postgres` / `redis` / `memcached` profile.

### `phpcacheadmin` — Redis + Memcached browser

**Starts:** `phpcacheadmin`. **Toggle:** `LDS_ENABLE_PHPCACHEADMIN`. **Off by
default** (turn it on when you run `redis`/`memcached`).

- Redis + Memcached + OPcache/APCu browser. `${CACHE_ADMIN_HOST}` (default
  `cache.test`) / host `${CACHE_ADMIN_HOST_PORT}` (default `4421`).
- Pre-pointed at the `redis` and `memcached` services — start one (or both) to
  see data. No volume (stateless UI).

### `dbgate` — web DB client

**Starts:** `dbgate`. **Toggle:** `LDS_ENABLE_DBGATE`. **On by default.**

- Web DB client. `${DB_ADMIN_HOST}` (default `db.test`) / host
  `${DB_ADMIN_HOST_PORT}` (default `4422`).
- Runs fully open (add/edit/delete connections in the UI); the stack's MySQL +
  Postgres are auto-listed via `scripts/run/dbgate-seed.*` (auto-run by `lds up`
  for the `dbgate`/`all` profile). UI-created connections persist in the
  `dbgate-data` volume.

## Realtime / pub-sub brokers — `soketi`, `centrifugo`, `emqx`

All three are **off by default**, **stateless** (no data volume → no disk creep),
and **mem/cpu-capped**. They speak **different** client protocols and are **not**
interchangeable — pick the one whose client protocol matches your app. One broker
serves unlimited channels/topics; you never run a second instance per channel.

### `soketi` — Pusher protocol

**Toggle:** `LDS_ENABLE_SOKETI`. Headless (no UI).

- **Image:** `quay.io/soketi/soketi:${SOKETI_VERSION}`. Port host
  `${SOKETI_HOST_PORT}` (default `4430`) → `6001`; also `${SOKETI_HOST}`
  (default `ws.test`) via the proxy.
- Drop-in for **Laravel broadcasting** (`BROADCAST_DRIVER=pusher`/reverb) +
  **Laravel Echo** / `pusher-js`. App credentials: `${SOKETI_APP_ID}` /
  `${SOKETI_APP_KEY}` / `${SOKETI_APP_SECRET}` (dev defaults — override for
  anything shared).
- Caps: `${SOKETI_MEM_LIMIT}` (default `256m`), `${SOKETI_CPUS}` (default `0.50`).

### `centrifugo` — raw WebSocket channels + admin UI

**Toggle:** `LDS_ENABLE_CENTRIFUGO`.

- **Image:** `centrifugo/centrifugo:${CENTRIFUGO_VERSION}`. Port host
  `${CENTRIFUGO_HOST_PORT}` (default `4431`) → `8000`; admin UI at
  `${CENTRIFUGO_HOST}` (default `centrifugo.test`).
- Clients use the **Centrifuge JS SDK** (not Echo). Runs in dev **insecure** mode
  (`--admin_insecure --client_insecure --api_insecure`) so you can pub/sub without
  minting JWTs — flip the flags off for auth. Keys: `${CENTRIFUGO_API_KEY}`,
  `${CENTRIFUGO_TOKEN_HMAC_SECRET_KEY}`, admin `${CENTRIFUGO_ADMIN_PASSWORD}`.
- Caps: `${CENTRIFUGO_MEM_LIMIT}` (default `256m`), `${CENTRIFUGO_CPUS}` (`0.50`).

### `emqx` — MQTT broker + dashboard

**Toggle:** `LDS_ENABLE_EMQX`. Heaviest of the three (Erlang VM) — higher caps.

- **Image:** `emqx/emqx:${EMQX_VERSION}`. Three ports: native MQTT host
  `${EMQX_MQTT_HOST_PORT}` (default `4432`) → `1883`; MQTT-over-WebSocket
  `${EMQX_WS_HOST_PORT}` (default `4433`) → `8083` (path `/mqtt`); dashboard
  `${EMQX_DASHBOARD_HOST_PORT}` (default `4434`) → `18083`, also
  `${EMQX_DASHBOARD_HOST}` (default `mqtt.test`).
- Clients use an **MQTT library** (MQTT.js / Paho in the browser, native MQTT for
  backends). Anonymous access allowed (dev). Dashboard login `admin` / `public`
  (change on first login). Wildcard `#` lets the dashboard watch every topic.
- Caps: `${EMQX_MEM_LIMIT}` (default `512m`), `${EMQX_CPUS}` (default `1.00`).

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
