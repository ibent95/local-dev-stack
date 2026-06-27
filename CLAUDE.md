# CLAUDE.md — local-dev-stack

Shared local dev infrastructure (Docker Compose) for all projects. Services are
gated behind **profiles** and share one external network `lds-network`.

## Layout

- `docker-compose.yml` — all services, each tagged with a profile.
- `docker-compose.https.yml` — opt-in TLS overlay for the `proxy` service (adds
  the `443` listener + certs mount + `HTTPS_METHOD`). Layered onto the base file
  by `up` only when `LDS_ENABLE_HTTPS=true`; never used alone.
- `.env.example` — copy to `.env`; all config is env-driven with defaults.
- `configs/` — per-service config: `php/` (Dockerfile + ini), `nginx/`
  (mass-vhost), `dns/` (dnsmasq image + conf), `web/dashboard/` (control panel
  `index.php` + `connectors.php`, a Kafka Connect connector builder that proxies
  both workers' REST APIs server-side and renders forms from their config
  schema),
  `redis/`, `mysql/init/`, `postgres/init/` (SQL run on first boot),
  `mongo/init/` (*.js/*.sh — NOT auto-run: DHI mongodb has no
  docker-entrypoint.sh / initdb.d hook; the RS is set up by `mongo-init`),
  `kafka/` (`controller.properties` + `broker.properties` — the KRaft node
  configs mounted into the DHI kafka image), `kafka/connect/` (Debezium connector
  JSON), `kafka/connect-generic/` (generic Connect: `connect-distributed.properties`
  + `plugins/`),
  `proxy/certs/` (git-ignored dev TLS certs minted by `lds certs`; mounted into
  nginx-proxy only by the HTTPS overlay).
- `www/` — example PHP project folders (parent dir set by `PHP_PROJECTS_PATH`,
  default `./www`); each `<folder>` is served at
  `<folder>.test`, docroot auto-detected (public/ > htdocs/ > root). Sample in
  `www/example/public/index.php`.
- `lds.sh` / `lds.bat` — single entrypoint dispatching to all scripts
  (`./lds.sh <cmd>`): init, network (status|create|rm|reset), build-bases, up,
  down, rm, start, logs, ps, register-connectors, hosts-sync, build-php. `rm`
  force-removes containers (`compose rm -fs`) per profile; `start` runs one full
  lifecycle (init → down → rm → build-bases if missing → up).
- `base-images/` — shared `lds/*` base images built once, reused by the stack +
  templates. All build **FROM Docker Hardened Images (DHI)** under
  `${DHI_REGISTRY:-dhi.io}` (the dev/`-dev` flavor → ships a shell + apt; DHI
  defaults to a non-root user, so each base does `USER root` for its build +
  runtime steps). `php` → the ONE PHP base `lds/php`: php-fpm + extensions +
  composer + nginx + supervisor + supercronic, bakes the global
  `configs/php-app/*` (default vhost + supervisord), `CMD supervisord`; built
  from the REPO ROOT (to COPY configs). **PHP is the DHI exception:** the
  `dhi.io/php` images are split (a minimal `-dev` build with no php-fpm + no
  `docker-php-ext-*` helpers, and a hardened `-fpm` runtime with no shell/apk),
  so neither can host the fat single container. Instead `lds/php` builds FROM
  `dhi.io/alpine-base:3.24-dev` and installs php-fpm + extensions + nginx +
  supervisor from Alpine's repos (`php` = `php84`). Alpine's curated DHI repo
  carries no php, so the Dockerfile adds the upstream Alpine `main`+`community`
  repos (same shape as debian-base pulling php from Debian). `rdkafka`, `redis`
  and `memcached` ship as apk packages (`php84-pecl-*`, which auto-enable their
  own conf.d ini); `apfd` (no apk package) is compiled via PECL using a throwaway
  `.build-deps` toolchain (gcc/make/phpize) that's `apk del`'d after, so the
  final image ships no compiler. Alpine `apk` has
  no init/postinst machinery, so there's none of the `adm`/`www-data`/
  `invoke-rc.d` daemon-postinst trouble Debian needs worked around. Compat shims
  keep the official-image layout the configs/mounts expect: `php-fpm84` (and
  `php84`/`phpize84`/`php-config84`) symlinked onto `$PATH`, the fpm pool on
  `127.0.0.1:9000` running as the `nginx` user, `/usr/local/etc/php/conf.d`
  symlinked to `/etc/php84/conf.d` (where the compose php service mounts its
  inis), and nginx's `conf.d` symlinked to `http.d` (Alpine includes `server{}`
  blocks from `http.d`, not `conf.d`). supervisord programs are env-toggled: `ENABLE_PHP`,
  `ENABLE_NGINX`, and `ENABLE_CRON` (generic `[program:cron]` = supercronic over
  `/etc/supervisor/crontab`, off by default). Framework templates keep their OWN
  scheduler/queue programs in `/etc/supervisor/conf.d/` (e.g. Laravel's
  `worker.conf`) rather than the generic one.
  The language bases build FROM their DHI per-language `-dev` image (exact
  pinned versions, hardened), all on the **Alpine (musl)** flavor for one OS
  family across the stack: `go-dev` (+air) `FROM dhi.io/golang:1.26-alpine3.24-dev`,
  `rust-dev` (+cargo-watch) `dhi.io/rust:1.96-alpine3.24-dev`, `node-dev`
  `dhi.io/node:26.3-alpine3.24-dev`, `python-dev` (+watchfiles)
  `dhi.io/python:3.14-alpine3.24-dev`, `java-dev` `dhi.io/eclipse-temurin:25-jdk-alpine3.24-dev`.
  DHI publishes no `maven:*` image, so `java-dev` installs Apache Maven from the
  archive.apache.org binary dist (Alpine's busybox `wget` + gzip-aware `tar`, no
  apk install needed). Note the musl tradeoff: Python wheels / Node native addons
  must have musl builds, else they compile from source. All dev bases also bake in **supercronic**
  (vendored from `assets/`, so their bake context is the repo root), so cron-*
  templates get it from the base locally instead of vendoring per-project.
  Versions are env-driven (`PHP_VERSION`, `GO_VERSION`, … in `.env`; the
  per-language OS/flavor suffix lives in each Dockerfile's `FROM`).
  Build: `./lds.sh build-bases` → `docker
  buildx bake -f docker-bake.hcl` (parallel; `--load` local, `--push` tags to
  `$REGISTRY` as a post-step). The LDS `php`
  service runs `lds/php` (supervisord → php-fpm + nginx, mounts the mass-vhost
  nginx config); every PHP template is `FROM lds/php`.
- `scripts/run/` — `init`, `exec` (run a command / open a shell in a service
  container via `docker compose exec` — pass the service name), `app`
  (`start|stop|restart|logs|ps [dir]` — manage a svc/web project via its own
  compose; `start` ensures proxy+dns+network then `up --build -d`; leaves shared
  LDS running), `new` (scaffold a project: `php` = plain mass-vhost
  folder under `PHP_PROJECTS_PATH`; everything else copies
  `templates/<role>-template-<tech>` into that tech's `*_PROJECTS_PATH` and
  rewrites name/container_name/host), `up`, `down` (removes containers), `stop`
  (`compose stop` — keeps containers for fast resume), `rm`, `start`, `logs`,
  `kafka-topics` (provisions `KAFKA_TOPICS`; auto-run by `up` for the kafka
  profile), `mysql-init` (creates the `app` database + `app` user — the DHI mysql
  entrypoint, unlike the official image, ignores `MYSQL_DATABASE`/`MYSQL_USER`/
  initdb.d, so this does it; auto-run by `up` for mysql/all; idempotent),
  `mongo-init` (initiates the single-node replica set `rs0` + creates
  the root/app users via the localhost exception + materializes the `app` db;
  auto-run by `up` for mongo/all;
  idempotent), `dbgate-seed` (writes `configs/dbgate/connections.seed.jsonl` into
  DBGate's volume so the stack DBs are auto-listed without the UI-locking
  `CONNECTIONS` env; idempotent, auto-run by `up` for dbgate/all),
  `certs` (mints the wildcard `*.test` dev TLS cert into `configs/proxy/certs/`
  via mkcert, else self-signed openssl; auto-run by `up` when `LDS_ENABLE_HTTPS`
  is on and the cert is missing; idempotent unless `--force`),
  `register-connectors`, `connect-plugin` (download+install a Connect plugin into
  the generic worker's `plugins/` dir — known Apache-2.0 connectors by shortname
  `jdbc`/`s3`/`http`/`opensearch`, or any release by URL; restart
  `lds-kafka-connect-generic` to load), `hosts-sync`. `scripts/build/` — `build-bases`,
  `build-php`. Each exists in
  BOTH `.sh` (bash) and `.bat` (Windows cmd); no `.ps1`.
- `templates/` — flat, one folder per template. Role prefix: `svc-template-<x>`
  = API (JSON), `web-template-<x>` = web UI app; most ship as a svc+web pair.
  NATIVE (language's own web tech, code included): `go` (net/http), `node`
  (http module), `python` (http.server), `java` (Jakarta Servlet on Tomcat/WAR),
  `rust` (axum — no Rust stdlib HTTP). FRAMEWORK (separate templates): Java —
  `springboot`/`micronaut`/`quarkus`/`vaadin` (vaadin web-only, Flow free core);
  Node — `express`; Python — `flask`/`fastapi` (code-included) + `django`
  (scaffolded); PHP — `laravel`/`symfony`/`codeigniter`/`cakephp` (php-fpm+nginx,
  scaffolded), `slim` (php-fpm+nginx, code-included), `webman` (long-running,
  no nginx, :8787); SPA — `angular`/`react` (web-only). JOB role —
  `cron-template-<tech>` (`shell`/`python`/`node`/`go`/`php`): CronJob-style via
  supercronic over a `crontab` + `job.*`, logs to stdout, no web port; scaffold
  via `lds new cron-<tech> <name>`; lands in that tech's `*_PROJECTS_PATH`
  (cron-python → `PYTHON_PROJECTS_PATH`, etc.), except `cron-shell` →
  `JOBS_PROJECTS_PATH` (bare `cron` = shell).
  Two Dockerfiles per project: `Dockerfile` (cloud/default — K8s/Fleet builds it)
  and `LDS.Dockerfile` (local — compose uses `build.dockerfile`). supercronic is
  vendored for the cloud image: `lds new cron-*` copies `assets/supersonic/<ver>/`
  into the project as `bin/supercronic` and the cloud `Dockerfile` COPYs it. The
  `LDS.Dockerfile` gets supercronic from the lds/* base (all dev bases now ship
  it) — except `cron-shell` (Alpine), which still vendors it.
  PHP-fpm frameworks put
  the fpm `app` on a per-project `internal` network and nginx bridges to
  `lds-network` (avoids `app` alias collisions). Java Servlet templates don't
  hot-reload (rebuild). Each is a
  standalone project with its own compose + `VIRTUAL_HOST`, on external lds-network.
- `docs/en`, `docs/id` — bilingual docs, modular numbered files
  (`01-overview.md` … `10-databases.md`) with a `README.md` index in each.

## Profiles

`proxy` `php` `mysql` `postgres` `mongo` `redis` `memcached` `kafka`
`phpcacheadmin` `dbgate` `drawdb` `hop` `superset` `semgrep` `soketi` `centrifugo` `emqx` `all`

`phpcacheadmin` and `dbgate` are the two web admin UIs, each on its OWN profile
(no `tools` umbrella — toggle them independently): **phpCacheAdmin** (`cache.test`
/ :4421, Redis+Memcached) and **DBGate** (`db.test` / :4422, pre-connected to
MySQL+Postgres). They need the matching data profile (and `proxy` for the `.test`
URL) running to be useful.

`soketi` / `centrifugo` / `emqx` = realtime / pub-sub WebSocket brokers (host ports
`443x`), all **off by default** and **stateless** (no volume → no disk creep), each
mem/cpu-capped. They speak DIFFERENT client protocols and are not interchangeable:
**Soketi** = Pusher protocol (Laravel Reverb/Echo + pusher-js compatible, headless,
:4430); **Centrifugo** = raw WebSocket channels + admin UI (Centrifuge JS SDK,
`centrifugo.test` / :4431, runs in dev `--*_insecure` mode); **EMQX** = MQTT +
MQTT-over-WebSocket + dashboard (MQTT.js/Paho clients, MQTT :4432, WS `/mqtt` :4433,
dashboard `mqtt.test` / :4434, anonymous allowed in dev, wildcard `#` lets the
dashboard watch every topic). One broker serves unlimited channels/topics.

Data tools (all **off by default**, own profiles): **DrawDB** = browser ER/schema
designer (`drawdb`, :4423 — open at `localhost:4423`, NOT `drawdb.test`: it needs
`crypto.randomUUID` which requires a secure context). **Apache Hop** = ETL designer
(`hop`, `hop.test` / :4424, image `apache/hop-web` Tomcat — NOT `apache/hop`
hop-server; no login, served at `/ui`; session timeout disabled; MySQL Connector/J
added via `configs/hop/jdbc-drivers/` single-file mount since it's not bundled).
**Apache Superset** = BI (`superset`, `superset.test` / :4425, DHI image, nonroot,
self-init via venv python, admin/admin, SQLite metadata in `superset-home`).
**Semgrep** = SAST, two services: `semgrep` (nginx SARIF viewer, `semgrep.test` /
:4426) + `semgrep-scan` (pinned `semgrep/semgrep` CLI, its own run-only profile so
it never auto-starts). `lds tools semgrep [path]` scans via `docker compose run
--rm semgrep-scan` → `report.sarif`, shown by the viewer.
Full detail: `docs/en/15-data-tools.md`. The `http://localhost` control panel
(`configs/web/dashboard/index.php`, served from `/var/lds-dashboard` outside the
project path) links every tool/project with live status — there is no
`__dashboard.test`.

### Default run-set (`LDS_ENABLE_*` toggles)

`.env` defines one independent boolean toggle per profile —
`LDS_ENABLE_<PROFILE>=true|false` (e.g. `LDS_ENABLE_MYSQL=true`). Defaults to
`proxy`, `php`, `mysql`, `dbgate` on; everything else off. `lds up` / `lds start` with **no
profile args** start exactly the set whose toggle is `true`; passing explicit
profiles (`lds up kafka`) ignores all toggles and starts only those. `up.sh` /
`up.bat` walk the canonical profile list and read each `LDS_ENABLE_<UPPER>` from
`.env` directly (we intentionally do NOT export `COMPOSE_PROFILES`, which Compose
would silently union with `--profile` flags and pollute scoped `up <profile>`
calls). If every toggle is false → falls back to `all`. To make a realtime
broker a default, flip its toggle (e.g. `LDS_ENABLE_SOKETI=true`). `proxy` has
its own toggle for running the edge proxy + DNS without PHP (when `php` is on,
proxy comes along regardless, since both live in the `php` profile).

## Conventions

- Container names prefixed `lds-`.
- All env via `${VAR:-default}`; healthchecks on every long-running service.
- **Docker Hardened Images (DHI):** base images, the DB services, and the dns
  image all come from DHI under `${DHI_REGISTRY:-dhi.io}`. Bases use the `-dev`
  flavor (shell + toolchain) and the Alpine line (`alpine3.24-dev`, php on
  `alpine-base:3.24-dev`). The DB services use the plain hardened runtime flavor
  (no `-dev` — not modified; their CLIs/`pg_isready`/`mysqladmin` keep the
  healthchecks working): `postgres`/`redis` on `*-alpine3.24`, `mysql`/`memcached`
  on `*-debian13` (DHI ships no Alpine variant for those two). **Mongo** is the
  exception — its runtime is mongod-only (no `mongosh`/shell), but it needs the
  shell (keyfile gen) + `mongosh` (`mongo-init` users + healthcheck), so it uses
  the `-dev` flavor (`mongodb:8.3-debian13-dev`). The dns image
  builds FROM `dhi.io/alpine-base:3.24-dev` (`apk`-installs dnsmasq from upstream
  Alpine main). Set `DHI_REGISTRY` in `.env` to repoint the namespace.
- `TZ=Asia/Jakarta`.
- Kafka is KRaft (no ZooKeeper): dedicated controller + broker, on **DHI**
  `${DHI_REGISTRY}/kafka:4.3-debian13` (Kafka 4.x). DHI kafka ignores `KAFKA_*`
  env — it reads a fixed `/opt/kafka/config/server.properties`, so the controller
  + broker mount `configs/kafka/{controller,broker}.properties`; `KAFKA_CLUSTER_ID`
  (shared) drives the entrypoint's auto storage-format. Runs as root (the DHI
  image is nonroot uid 65532, which can't write the data volume).
- Two Kafka Connect workers (different images/plugins):
  `connect-debezium` = Debezium image (`quay.io/debezium`, no DHI variant; CDC
  sources, REST host :4413); `connect-generic` = the DHI `kafka` image run as a
  Connect worker (entrypoint → `connect-distributed.sh` + mounted properties; no
  bundled connectors beyond Kafka's built-in MirrorMaker ones — add more with
  `lds connect-plugin <jdbc|s3|http|opensearch|URL>` (drops them into
  `configs/kafka/connect-generic/plugins/`; restart the worker to load),
  REST host :4412). Each uses its own group + state topics. MySQL has binlog/GTID,
  Postgres has logical WAL.
- Schema Registry = Apicurio Registry (Apache 2.0, `apicurio-registry-mem`),
  in-memory. Avro values via Apicurio's Connect converter (the Debezium worker
  sets `ENABLE_APICURIO_CONVERTERS`; converter URL/props are per-connector in
  the `*-connector.json` files). kafka-ui reads schemas via the ccompat API
  (`/apis/ccompat/v7`). No Confluent images remain.
- All three primary DBs are CDC-ready: MySQL binlog/GTID, Postgres logical WAL,
  Mongo a single-node replica set (`rs0`) **with auth** (root + app users, like
  mysql/postgres). Replica set + auth mandates a keyfile (internal auth),
  auto-generated into the `mongo-config` volume on first boot; RS + users
  bootstrapped by `mongo-init`. Uses `dhi.io/mongodb:8.3-debian13-dev` for the
  shell (keyfile) + `mongosh` (users + healthcheck); mongod runs as root (the
  DHI image default — no `docker-entrypoint.sh` wrapper to drop privileges).
- Web = Devilbox-style: nginx mass vhosting + dnsmasq (*.test -> 127.0.0.1).
  Web on host port 80 for clean URLs; needs adapter DNS -> 127.0.0.1 (or run
  hosts-sync.sh). TLD `.test` is referenced in BOTH nginx + dnsmasq configs.
- HTTP by default (no certs). HTTPS is an opt-in overlay, NOT a compose profile:
  `LDS_ENABLE_HTTPS=true` makes `up` layer `docker-compose.https.yml` (TLS on the
  proxy :443 via a wildcard `*.test` cert from `lds certs`) onto the base file.
  `HTTPS_METHOD=noredirect` keeps http+https both live. TLS terminates at the
  proxy; the php/app containers stay http on :80 internally.

## Common commands

```bash
./lds.sh build-bases               # one-time: build lds/* base images
./lds.sh up kafka                  # start a profile
./lds.sh down -v                   # stop + wipe data
./lds.sh ps                        # status of everything
```

## Gotchas

- Set `KAFKA_CLUSTER_ID` before first Kafka start; changing it later requires
  wiping the `kafka-*-data` volumes.
- Schema Registry (Apicurio) / Connect (Debezium + the DHI kafka image) run
  against the DHI kafka broker (4.x). Debezium, Apicurio, and kafka-ui have no
  DHI images, so they stay on `quay.io/debezium` / `apicurio/` / `ghcr.io/kafbat`;
  all are Apache-/open-licensed and tags are env-swappable.
