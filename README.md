# local-dev-stack

Shared local development infrastructure for all your projects, as Docker
Compose services gated behind **profiles**. Start only what you need; every
service joins one shared network (`lds-network`) so your application containers can
talk to them.

## Services

<table>
<thead>
<tr>
<th>Group</th>
<th>Profile</th>
<th>Service(s)</th>
<th>Host port(s)</th>
</tr>
</thead>
<tbody>
<tr>
<td>MySQL</td>
<td>`mysql`</td>
<td>`mysql` (8.4, binlog ON for CDC)</td>
<td>4400</td>
</tr>
<tr>
<td>PostgreSQL</td>
<td>`postgres`</td>
<td>`postgres` (16, `wal_level=logical` for CDC)</td>
<td>4401</td>
</tr>
<tr>
<td>MongoDB</td>
<td>`mongo`</td>
<td>`mongo` (7, single-node replica set `rs0`, CDC-ready)</td>
<td>4402</td>
</tr>
<tr>
<td>Redis</td>
<td>`redis`</td>
<td>`redis` (7)</td>
<td>4403</td>
</tr>
<tr>
<td>Memcached</td>
<td>`memcached`</td>
<td>`memcached` (1.6)</td>
<td>4404</td>
</tr>
<tr>
<td>Proxy/DNS</td>
<td>`proxy`</td>
<td>`proxy` (nginx-proxy edge router), `dns` (dnsmasq)</td>
<td>80 (web), 53 (dns)</td>
</tr>
<tr>
<td>Web (PHP)</td>
<td>`php`</td>
<td>`php` — one container, supervisord runs php-fpm + nginx (multi-project)</td>
<td>via proxy</td>
</tr>
<tr>
<td>Apps</td>
<td>_templates_</td>
<td>Go / Rust / Java / Node containers (own compose)</td>
<td>via proxy</td>
</tr>
<tr>
<td>Kafka</td>
<td>`kafka`</td>
<td>`kafka-controller`, `kafka-broker`, `schema-registry` (Apicurio), `connect-debezium`, `connect-generic`, `kafka-ui`</td>
<td>4410–4413, 4420</td>
</tr>
<tr>
<td>Realtime</td>
<td>`soketi` / `centrifugo` / `mqtt`</td>
<td>WebSocket / MQTT pub-sub brokers — **off by default**, stateless</td>
<td>4430 / 4431 / 4432–4434</td>
</tr>
<tr>
<td>Admin UIs</td>
<td>`phpcacheadmin` / `dbgate`</td>
<td>cache browser / web DB client</td>
<td>4421 / 4422</td>
</tr>
<tr>
<td>DB design</td>
<td>`drawdb`</td>
<td>DrawDB — ER diagram designer (open at `localhost:4423`)</td>
<td>4423</td>
</tr>
<tr>
<td>Warehouse/BI</td>
<td>`hop` / `superset`</td>
<td>Apache Hop (ETL designer) / Apache Superset (BI)</td>
<td>4424 / 4425</td>
</tr>
<tr>
<td>Code quality</td>
<td>`semgrep`</td>
<td>Semgrep SARIF viewer (`lds tools semgrep` runs the scan)</td>
<td>4426</td>
</tr>
<tr>
<td>Security/Auth</td>
<td>`vaultwarden`</td>
<td>Vaultwarden password manager (Bitwarden-compatible)</td>
<td>4429</td>
</tr>
<tr>
<td>Web analytics</td>
<td>`insighttrack`</td>
<td>InsightTrack dashboard + API (reuses shared `postgres`)</td>
<td>4427 / 4428</td>
</tr>
<tr>
<td>Project management</td>
<td>`werkyn`</td>
<td>Werkyn team project management/collaboration app (reuses shared `postgres`)</td>
<td>4435</td>
</tr>
</tbody>
</table>

> **Realtime brokers** are three independent choices for WebSocket pub/sub, each
> speaking a *different client protocol* (so pick the one matching your app):
> **Soketi** (Pusher protocol — drop-in for Laravel Reverb broadcasting + Laravel
> Echo / pusher-js), **Centrifugo** (raw WebSocket channels + admin UI, Centrifuge
> JS SDK), **MQTT (Mosquitto + MQTTX)** (MQTT + MQTT-over-WebSocket via Mosquitto
> with a browser client at `mqtt.test`; clients use MQTT.js / Paho). One broker serves
> unlimited channels/topics — you never run a second one per channel. All three are
> stateless (no data volume) and mem/cpu-capped. Start one with `lds up soketi` /
> `centrifugo` / `mqtt`.

**PHP extensions:** rdkafka, redis, memcached, pdo_mysql, pdo_pgsql, opcache,
intl, bcmath, gd, zip, sockets + composer.

## Quick start

Everything runs through the single **`lds`** wrapper (`./lds.sh <cmd>` or
`lds.bat <cmd>` on Windows `cmd`):

```bash
cp .env.example .env             # then edit if needed
./lds.sh init                    # one-time: create the shared lds-network network
./lds.sh build-bases             # one-time: build the lds/* base images

# Start the groups you need (any combination of profiles):
./lds.sh up                      # the default run-set (LDS_ENABLE_* toggles in .env)
./lds.sh up mysql postgres redis memcached
./lds.sh up php                  # (auto-builds the lds/php base if missing)
./lds.sh up kafka
./lds.sh up insighttrack
./lds.sh up vaultwarden
./lds.sh up werkyn
./lds.sh up mqtt                 # a realtime broker (soketi | centrifugo | mqtt)
./lds.sh up all                  # or everything at once

./lds.sh down                    # stop (add -v to wipe data)
./lds.sh help                    # all commands
```

> **Default run-set:** `lds up` with no arguments starts every profile whose
> **`LDS_ENABLE_<PROFILE>`** toggle in `.env` is `true` (defaults: `proxy`, `php`,
> `mysql`, `dbgate` on → edge proxy, DNS, PHP, MySQL, DBGate).
> One independent on/off switch per service — flip a single line (e.g.
> `LDS_ENABLE_KAFKA=true`) to add/remove a group. Passing explicit profiles
> (`lds up kafka`) ignores the toggles and starts only those.

> `lds` just dispatches to the scripts in `scripts/`. Every script also exists
> standalone in two forms: **`.sh`** (bash / Git Bash / WSL / Linux) and
> **`.bat`** (Windows `cmd`) — e.g. `scripts/run/up.sh` / `up.bat`.

### Base images

The PHP extension set and each language's dev tooling (air, cargo-watch, Maven,
…) are built **once** into shared `lds/*` base images, then reused by the stack
and every template. Build/refresh them with `./lds.sh build-bases` (`--force` to
rebuild, `--push` to push to `$REGISTRY`). Sources live in `base-images/`; the
build is orchestrated by **`docker-bake.hcl`** (`docker buildx bake`), so all
six images build in parallel from one declarative definition.

Raw Compose equivalents:

```bash
docker compose --profile mysql --profile redis up -d
docker compose --profile kafka up -d
docker compose --profile '*' down
```

## Endpoints

- **Control panel / dashboard:** http://localhost
- **Your projects:** http://&lt;folder&gt;.test  (e.g. http://example.test)

All host ports live in the **`44xx`** block (set via `*_HOST_PORT` in `.env`).
From other containers on `lds-network`, use the service name + its internal port
(right column) instead. Full reference: [docs/en/12-ports.md](docs/en/12-ports.md).

<table>
<thead>
<tr>
<th>Group</th>
<th>Service</th>
<th>Host + Port</th>
<th>From Container + Port</th>
</tr>
</thead>
<tbody>
<tr>
<td>**Data** `440x`</td>
<td>--------------------------------------------------------------------------------</td>
<td></td>
<td></td>
</tr>
<tr>
<td></td>
<td>MySQL</td>
<td>`localhost:4400`</td>
<td>`mysql:3306`</td>
</tr>
<tr>
<td></td>
<td>PostgreSQL</td>
<td>`localhost:4401`</td>
<td>`postgres:5432`</td>
</tr>
<tr>
<td></td>
<td>MongoDB</td>
<td>`localhost:4402`</td>
<td>`mongo:27017`</td>
</tr>
<tr>
<td></td>
<td>Redis</td>
<td>`localhost:4403`</td>
<td>`redis:6379`</td>
</tr>
<tr>
<td></td>
<td>Memcached</td>
<td>`localhost:4404`</td>
<td>`memcached:11211`</td>
</tr>
<tr>
<td>**Kafka** `441x`</td>
<td>--------------------------------------------------------------------------------</td>
<td></td>
<td></td>
</tr>
<tr>
<td></td>
<td>Broker (bootstrap)</td>
<td>`localhost:4410`</td>
<td>`kafka-broker:9092`</td>
</tr>
<tr>
<td></td>
<td>Schema Registry</td>
<td>`localhost:4411`</td>
<td>`schema-registry:8080`</td>
</tr>
<tr>
<td></td>
<td>Connect — generic</td>
<td>`localhost:4412`</td>
<td>`connect-generic:8083`</td>
</tr>
<tr>
<td></td>
<td>Connect — Debezium</td>
<td>`localhost:4413`</td>
<td>`connect-debezium:8083`</td>
</tr>
<tr>
<td>**Web UIs** `442x+`</td>
<td>-------------------------------------------------------------------------------</td>
<td></td>
<td></td>
</tr>
<tr>
<td></td>
<td>Kafka UI</td>
<td>`localhost:4420`</td>
<td>`kafka-ui:8080`</td>
</tr>
<tr>
<td></td>
<td>phpCacheAdmin</td>
<td>`localhost:4421` (`cache.test`)</td>
<td>`phpcacheadmin:80`</td>
</tr>
<tr>
<td></td>
<td>DBGate</td>
<td>`localhost:4422` (`db.test`)</td>
<td>`dbgate:3000`</td>
</tr>
<tr>
<td></td>
<td>DrawDB</td>
<td>`localhost:4423` (**not** `drawdb.test`)</td>
<td>`drawdb:80`</td>
</tr>
<tr>
<td></td>
<td>Apache Hop</td>
<td>`localhost:4424` (`hop.test`)</td>
<td>`hop:8080`</td>
</tr>
<tr>
<td></td>
<td>Apache Superset</td>
<td>`localhost:4425` (`superset.test`)</td>
<td>`superset:8088`</td>
</tr>
<tr>
<td></td>
<td>Semgrep viewer</td>
<td>`localhost:4426` (`semgrep.test`)</td>
<td>`semgrep:80`</td>
</tr>
<tr>
<td></td>
<td>InsightTrack UI</td>
<td>`localhost:4427` (`insighttrack.test`)</td>
<td>`insighttrack:4173`</td>
</tr>
<tr>
<td></td>
<td>InsightTrack API</td>
<td>`localhost:4428`</td>
<td>`insighttrack-backend:3001`</td>
</tr>
<tr>
<td></td>
<td>Vaultwarden</td>
<td>`localhost:4429` (`vaultwarden.test`)</td>
<td>`vaultwarden:80`</td>
</tr>
<tr>
<td></td>
<td>Werkyn</td>
<td>`localhost:4435` (`werkyn.test`)</td>
<td>`werkyn:3000`</td>
</tr>
<tr>
<td>**Realtime** `443x`</td>
<td>--------------------------------------------------------------------------------</td>
<td></td>
<td></td>
</tr>
<tr>
<td></td>
<td>Soketi (Pusher)</td>
<td>`localhost:4430` (`ws.test`)</td>
<td>`soketi:6001`</td>
</tr>
<tr>
<td></td>
<td>Centrifugo + UI</td>
<td>`localhost:4431` (`centrifugo.test`)</td>
<td>`centrifugo:8000`</td>
</tr>
<tr>
<td></td>
<td>Mosquitto — MQTT</td>
<td>`localhost:4432`</td>
<td>`mosquitto:1883`</td>
</tr>
<tr>
<td></td>
<td>Mosquitto — MQTT/WS</td>
<td>`localhost:4433` (path `/`)</td>
<td>`mosquitto:9001`</td>
</tr>
<tr>
<td></td>
<td>MQTTX web client</td>
<td>`localhost:4434` (`mqtt.test`)</td>
<td>`mqttx:80`</td>
</tr>
<tr>
<td>**Infra**</td>
<td>--------------------------------------------------------------------------------</td>
<td></td>
<td></td>
</tr>
<tr>
<td></td>
<td>Web proxy</td>
<td>`localhost:80` (`*.test`)</td>
<td>—</td>
</tr>
<tr>
<td></td>
<td>DNS</td>
<td>`localhost:53` (udp + tcp)</td>
<td>—</td>
</tr>
</tbody>
</table>

## Hosting your projects (Devilbox-style)

The `php` profile runs one container (supervisord → php-fpm + nginx) doing
**mass virtual hosting**, plus a dnsmasq DNS server. Every folder under `www/`
is served automatically:

```
www/
  example/public/index.php   ->  http://example.test
  myshop/public/index.php    ->  http://myshop.test
  legacy-site/index.php      ->  http://legacy-site.test
```

Docroot per project is auto-detected: `public/` → `htdocs/` → folder root.
No per-project config, no rebuild — drop a folder and refresh.

**One-time DNS setup (so `*.test` resolves):** point your Windows network
adapter's DNS server to `127.0.0.1`. The `dns` container then answers `*.test`
with `127.0.0.1` and forwards all other lookups upstream (8.8.8.8/1.1.1.1), so
normal internet DNS keeps working while the stack is up.

> Prefer not to change your system DNS? Run `scripts/run/hosts-sync.bat` in an
> **admin** command prompt (or `hosts-sync.sh` with sudo) — it writes each
> project into your hosts file. (Re-run it whenever you add a project.)

Mount a different folder by setting `PHP_PROJECTS_PATH` in `.env` (e.g. point it
at `D:/projects/PHP` to serve all your existing projects at once). It defaults to
`./www`, the example folder shipped with LDS.

## Hosting other languages (Go / Rust / Java / Node …)

PHP shares one runtime, so folders are enough. Compiled/runtime apps each run
as their own container and get a `.test` hostname through the **nginx-proxy**
edge router. Any container that sets `VIRTUAL_HOST` + `VIRTUAL_PORT` and joins
`lds-network` is routed automatically:

```yaml
    environment:
      VIRTUAL_HOST: orders.test
      VIRTUAL_PORT: "8080"
    networks: [lds-network]
networks:
  lds-network:
    external: true
```

Ready-to-run starters live in `templates/`, named by role (`svc-` = API,
`web-` = UI app) and by native-vs-framework. Native (language's own web tech):
`go` (net/http), `node` (http module), `python` (http.server), `java` (Servlet),
plus `rust` (axum). Frameworks (separate templates): Java — `springboot`,
`micronaut`, `quarkus`, `vaadin`; Node — `express`; Python — `flask`, `fastapi`,
`django`; PHP — `laravel`, `symfony`, `slim`, `webman`, `codeigniter`,
`cakephp`; SPA — `angular`, `react`. Most ship as a `svc-`+`web-` pair. Bring up the router once with
`./scripts/run/up.sh proxy`, then `docker compose up -d` in a template. See
`templates/README.md`.

## Creating a new project

Fastest way — the **`lds new`** scaffolder (the cross-language equivalent of
dropping a PHP folder):

```bash
lds new php   myblog          # plain PHP under PHP_PROJECTS_PATH -> http://myblog.test
lds new go    orders          # web template by default
lds new svc-python rates      # the svc-template-python API
lds new web-laravel shop shop.test   # framework + custom host
```

It copies the matching `templates/<role>-template-<tech>` into that technology's
`*_PROJECTS_PATH` (set in `.env` — `GO_PROJECTS_PATH`, `RUST_PROJECTS_PATH`,
`NODE_PROJECTS_PATH`, `PYTHON_PROJECTS_PATH`, `JAVA_PROJECTS_PATH`; PHP uses
`PHP_PROJECTS_PATH`), and rewrites the template's `name`/`container_name`/host to
your project name.

Then manage it with **`lds app <command>`** — `start` ensures the
proxy/dns/network are up and runs `docker compose up --build -d` for you:

```bash
cd ../../Go/orders
lds app start        # build & start (+ proxy)   | lds app start ../../Go/orders
lds app logs         # tail logs
lds app restart      # rebuild & recreate
lds app stop         # stop  (add -v to wipe its volumes)
```

(Plain PHP projects need none of this — they're served immediately by the shared
`php` container.)

Under the hood it's just copy-rename-run — you **never edit `local-dev-stack`'s
own files**, and you can still do it by hand:

```bash
cp -r templates/svc-template-go  D:/projects/Golang/orders   # 1. copy (anywhere)
# 2. set APP_HOST=orders.test in the project's .env (or its compose file)
cd D:/projects/Golang/orders && docker compose up -d         # 3. -> http://orders.test
```

- **No `public/`/index page needed** for a template — that requirement is only
  for plain PHP dropped into `www/` (the shared mass-vhost). A template runs its
  own server; it just listens on its `VIRTUAL_PORT`.
- **No registration in LDS** — nothing is added to `local-dev-stack/docker-compose.yml`.
  New hostnames work automatically: `dns` resolves `*.test` by **wildcard**, and
  `proxy` **auto-discovers** any container that sets `VIRTUAL_HOST`.
- **Standing requirements:** `./scripts/run/init.sh` once (create `lds-network`) +
  point your Windows adapter DNS at `127.0.0.1`; keep `./scripts/run/up.sh proxy`
  running. Templates already join `lds-network` and set `VIRTUAL_HOST`.

> Not changing system DNS? Use `hosts-sync.bat` (admin) / `hosts-sync.sh`
> instead — but re-run it per new project (the hosts file has no wildcard).

## Connecting your own project

`lds-network` is an **independent external network** — create it once with
`./scripts/run/init.sh` (or `docker network create lds-network`). After that, the
stack and every project attach to it as equals; nothing owns its lifecycle, so
order of startup/shutdown never matters. (`up.sh` also auto-creates it.)

Point your project's compose file at it:

```yaml
networks:
  lds-network:
    external: true
```

Then your app reaches services by name (in-network ports): `mysql`, `postgres`,
`redis`, `memcached`, `kafka-broker:9092`, `schema-registry:8080`,
`connect-debezium:8083`, `connect-generic:8083`. From the host, Connect is on
:4413 (Debezium) and :4412 (generic), and the registry on :4411.

## Debezium CDC

The `connect-debezium` service is the Debezium Connect image with MySQL and
Postgres connectors built in. MySQL runs with binlog (ROW + GTID); Postgres runs
with `wal_level=logical` — both ready for change data capture. A second worker,
`connect-generic` (vanilla apache/kafka image), is there for non-Debezium
connectors — drop plugin JARs into `configs/kafka/connect-generic/plugins/`.

Register the example connectors once Kafka + a DB are up:

```powershell
./scripts/run/register-connectors.sh          # all
./scripts/run/register-connectors.sh mysql    # just MySQL
```

Edit the configs in `configs/kafka/connect/*.json` to match your databases.

Prefer a UI? The control panel (`http://localhost/`) has a **connector builder**
at `http://localhost/connectors.php`: pick a worker (Debezium or generic), pick a
plugin, and it renders a guided form from that connector's own config schema —
with live validation — then creates it. Lists and deletes existing connectors too.

## Notes

- All Kafka images are Apache-licensed: the broker/controller and generic
  Connect worker are `apache/kafka`, CDC is the (Apache-2.0) Debezium image, and
  the Schema Registry is Apicurio Registry (Apache 2.0) — no Confluent images.
  Avro values use Apicurio's Connect converter (`ENABLE_APICURIO_CONVERTERS` on
  the Debezium worker + per-connector converter config). Swap versions via
  `.env` (`APICURIO_VERSION`, `DEBEZIUM_VERSION`, `KAFKA_VERSION`, `KAFKA_UI_IMAGE`).
- Generate a fresh KRaft cluster id:
  `docker run --rm apache/kafka:3.9.1 /opt/kafka/bin/kafka-storage.sh random-uuid`
  and set `KAFKA_CLUSTER_ID` in `.env` **before first start**.

See `docs/en` (English) and `docs/id` (Bahasa Indonesia) for more detail.
