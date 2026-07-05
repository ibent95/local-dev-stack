# Copilot instructions for `local-dev-stack`

## Build, test, and lint commands

Use `./lds.sh` on bash/Linux/macOS or `lds.bat` on Windows `cmd`.

| Task | Command |
|---|---|
| First-time setup | `cp .env.example .env && ./lds.sh init` |
| Build all shared base images | `./lds.sh build-bases` |
| Force-rebuild base images | `./lds.sh build-bases --force` |
| Build only the PHP base image | `./lds.sh build-php` |
| Start stack (default profile toggles from `.env`) | `./lds.sh up` |
| Start only selected profiles | `./lds.sh up mysql redis` |
| Full reset lifecycle (`init -> down -> rm -> build-if-missing -> up`) | `./lds.sh start [profiles...]` |
| Stop and remove containers | `./lds.sh down` |
| Stop/remove and wipe volumes | `./lds.sh down -v` |
| Service status | `./lds.sh ps` |
| Service logs | `./lds.sh logs [service]` |
| Lint / static analysis (full target path) | `./lds.sh tools semgrep [path]` |
| Lint / static analysis (single target example) | `./lds.sh tools semgrep ./scripts/run` |
| Validate compose changes | `docker compose config --quiet` |

There is no repository-wide unit/integration test runner at repo root; validation is done via Compose/service health plus targeted Semgrep scans.

## High-level architecture

1. **Single wrapper CLI over shell scripts.** `lds.sh`/`lds.bat` dispatch into `scripts/run/*` and `scripts/build/*`; most behavior changes should be made in both `.sh` and `.bat` implementations.
2. **Profile-gated Compose stack.** `docker-compose.yml` defines all services under profiles; `scripts/run/up.(sh|bat)` computes which profiles to start from explicit args or `LDS_ENABLE_*` toggles in `.env`.
3. **Optional HTTPS is an overlay, not a profile.** When `LDS_ENABLE_HTTPS=true` and a proxy/php/all run-set is selected, `up` layers `docker-compose.https.yml` on top of `docker-compose.yml` and ensures wildcard certs exist (`lds certs`).
4. **Shared routing backbone.** `proxy` (nginx-proxy) + `dns` (dnsmasq) route `*.test`; all stack services and user projects join the external `lds-network`.
5. **Two app-hosting modes.**
   - **Plain PHP folders** in `PHP_PROJECTS_PATH` are served by one shared `php` container via mass vhost (docroot auto-detect: `public/` -> `htdocs/` -> root).
   - **Non-PHP apps** are independent template projects (`templates/*`) with their own compose files using `VIRTUAL_HOST`/`VIRTUAL_PORT` on `lds-network`.
6. **`up` performs post-start initialization hooks.** After compose up, scripts auto-run profile-coupled tasks such as `dbgate-seed`, `mysql-init`, `mongo-init`, `kafka-topics`, and `hop-register`.
7. **Kafka and Semgrep are split intentionally.**
   - Kafka uses KRaft controller+broker, Apicurio registry, and two Connect workers (`connect-debezium`, `connect-generic`).
   - Semgrep separates long-running viewer (`semgrep`) from one-shot scanner (`semgrep-scan`), invoked by `lds tools semgrep`.

## Key conventions for this repository

- **Keep profile definitions synchronized** across `scripts/run/up.sh`, `scripts/run/up.bat`, and `.env.example` (`LDS_ENABLE_<PROFILE>` toggles).
- **Do not rely on `COMPOSE_PROFILES`** for default behavior; `up` reads toggles directly so explicit `up <profile>` remains scoped.
- **Use service/container names on `lds-network` for inter-container access**, not host ports.
- **Container names are `lds-*` and Compose env values use `${VAR:-default}` style defaults.**
- **`http://localhost` dashboard is served from `configs/web/dashboard` outside project roots** (no `__dashboard.test` host).
- **If changing the dev TLD, update both** `configs/nginx/default.conf` **and** `configs/dns/dnsmasq.conf`.
- **Prefer targeted profile operations** (`lds up <profile>`) over `lds up all`; `all` is heavy.
- **Semgrep scanning on Windows intentionally uses `docker run` in script wrappers** for reliable volume mounting with drive-letter paths.
