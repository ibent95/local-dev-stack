# Service templates

Runnable starter apps for non-PHP stacks. Each is a self-contained container
that joins the shared `lds-network` network and gets a `.test` hostname via
**nginx-proxy** — no per-app proxy config.

Two naming axes:
- **Role prefix** — `svc-template-<x>` = API (returns JSON); `web-template-<x>` =
  web app with a UI (server-rendered or SPA). Most stacks ship as a svc+web pair.
- **Native vs framework** — language templates use the language's **native** web
  tech; frameworks are **separate** templates named after the framework.

### APIs (`svc-`, return JSON)

| Template                   | Stack (web tech)              | Hot reload  | Default URL                          | Code       |
|----------------------------|-------------------------------|-------------|--------------------------------------|------------|
| `svc-template-go`          | Go — `net/http` (native)      | air         | http://svc-template-go.test          | included   |
| `svc-template-node`        | Node — `http` module (native) | tsx watch   | http://svc-template-node.test        | included   |
| `svc-template-python`      | Python — `http.server` (native)| watchfiles | http://svc-template-python.test      | included   |
| `svc-template-java`        | Java — Servlet (native)       | rebuild     | http://svc-template-java.test        | included   |
| `svc-template-rust`        | Rust — axum                   | cargo-watch | http://svc-template-rust.test        | included   |
| `svc-template-springboot`  | Java — Spring Boot            | devtools    | http://svc-template-springboot.test  | included   |
| `svc-template-express`     | Node — Express                | tsx watch   | http://svc-template-express.test     | included   |
| `svc-template-flask`       | Python — Flask                | flask debug | http://svc-template-flask.test       | included   |
| `svc-template-fastapi`     | Python — FastAPI              | uvicorn     | http://svc-template-fastapi.test     | included   |
| `svc-template-django`      | Python — Django + DRF         | runserver   | http://svc-template-django.test      | scaffolded |
| `svc-template-laravel`     | PHP — Laravel (API-only)      | php-fpm     | http://svc-template-laravel.test     | scaffolded |
| `svc-template-symfony`     | PHP — Symfony (skeleton)      | php-fpm     | http://svc-template-symfony.test     | scaffolded |
| `svc-template-slim`        | PHP — Slim (micro)            | php-fpm     | http://svc-template-slim.test        | included   |
| `svc-template-webman`      | PHP — Webman (workerman)      | restart     | http://svc-template-webman.test      | scaffolded |
| `svc-template-codeigniter` | PHP — CodeIgniter 4           | php-fpm     | http://svc-template-codeigniter.test | scaffolded |
| `svc-template-cakephp`     | PHP — CakePHP                 | php-fpm     | http://svc-template-cakephp.test     | scaffolded |
| `svc-template-micronaut`   | Java — Micronaut              | mn:run      | http://svc-template-micronaut.test   | scaffolded |
| `svc-template-quarkus`     | Java — Quarkus                | quarkus:dev | http://svc-template-quarkus.test     | scaffolded |

### Web apps (`web-`, serve a UI)

| Template                   | Stack (web tech)                 | Hot reload   | Default URL                          | Code       |
|----------------------------|----------------------------------|--------------|--------------------------------------|------------|
| `web-template-go`          | Go — `html/template` (native)    | air          | http://web-template-go.test          | included   |
| `web-template-node`        | Node — `http` module (native)    | tsx watch    | http://web-template-node.test        | included   |
| `web-template-python`      | Python — `http.server` (native)  | watchfiles   | http://web-template-python.test      | included   |
| `web-template-java`        | Java — Servlet (native)          | rebuild      | http://web-template-java.test        | included   |
| `web-template-rust`        | Rust — axum (HTML)               | cargo-watch  | http://web-template-rust.test        | included   |
| `web-template-springboot`  | Java — Spring Boot + Thymeleaf   | devtools     | http://web-template-springboot.test  | included   |
| `web-template-express`     | Node — Express (HTML)            | tsx watch    | http://web-template-express.test     | included   |
| `web-template-flask`       | Python — Flask (HTML)            | flask debug  | http://web-template-flask.test       | included   |
| `web-template-fastapi`     | Python — FastAPI (HTML)          | uvicorn      | http://web-template-fastapi.test     | included   |
| `web-template-django`      | Python — Django (templates)      | runserver    | http://web-template-django.test      | scaffolded |
| `web-template-laravel`     | PHP — Laravel (Blade + Vite)     | php-fpm/vite | http://web-template-laravel.test     | scaffolded |
| `web-template-symfony`     | PHP — Symfony (webapp/Twig)      | php-fpm      | http://web-template-symfony.test     | scaffolded |
| `web-template-slim`        | PHP — Slim (HTML)                | php-fpm      | http://web-template-slim.test        | included   |
| `web-template-webman`      | PHP — Webman (workerman)         | restart      | http://web-template-webman.test      | scaffolded |
| `web-template-codeigniter` | PHP — CodeIgniter 4 (views)      | php-fpm      | http://web-template-codeigniter.test | scaffolded |
| `web-template-cakephp`     | PHP — CakePHP (views)            | php-fpm      | http://web-template-cakephp.test     | scaffolded |
| `web-template-micronaut`   | Java — Micronaut (views)         | mn:run       | http://web-template-micronaut.test   | scaffolded |
| `web-template-quarkus`     | Java — Quarkus (Qute)            | quarkus:dev  | http://web-template-quarkus.test     | scaffolded |
| `web-template-vaadin`      | Java — Vaadin (Flow, free core)  | spring-boot  | http://web-template-vaadin.test      | scaffolded |
| `web-template-angular`     | Angular (SPA)                    | ng/HMR       | http://web-template-angular.test     | scaffolded |
| `web-template-react`       | React + Vite (SPA)               | vite HMR     | http://web-template-react.test       | scaffolded |

`go`, `node`, `python`, `java` are **native** (Go `net/http`, Node `http`,
Python `http.server`, Java Servlet; Rust uses axum as it has no stdlib HTTP
server). Frameworks (separate templates): `springboot`, `micronaut`, `quarkus`,
`vaadin` (Java) · `express` (Node) · `flask`, `fastapi`, `django` (Python) ·
`laravel`, `symfony`, `slim`, `webman`, `codeigniter`, `cakephp` (PHP) ·
`angular`, `react` (SPA).

- **Code included** — run and go.
- **Scaffolded** — the folder is just the container + proxy wiring; the real
  framework is generated into `./src` by its own CLI on first use (always
  up-to-date). Each README has the one-line scaffold command.
- **Java note** — native Servlet templates run on Tomcat (WAR) and don't
  hot-reload; apply changes with `docker compose up -d --build`.

## Scheduled jobs — the `cron` role

`cron-template-<tech>` runs a task on a schedule via supercronic (no web port).
Scaffold with `lds new cron-<tech> <name>` → lands in that tech's
`*_PROJECTS_PATH` (cron-python → `PYTHON_PROJECTS_PATH`, etc.); `cron-shell`
uses `JOBS_PROJECTS_PATH`.

| Template | Language | crontab runs |
|---|---|---|
| `cron-template-shell`  | POSIX shell | `/app/job.sh` |
| `cron-template-python` | Python      | `python /app/job.py` |
| `cron-template-node`   | Node.js     | `node /app/job.js` |
| `cron-template-go`     | Go (compiled → binary) | `/app/job` |
| `cron-template-php`    | PHP (CLI)   | `php /app/job.php` |

Manage with `lds app start|logs|stop`. See `docs/en/11-cron-jobs.md`.

Every template is a **separate, standalone project** with its own
`docker-compose.yml` and its own proxy entry (`VIRTUAL_HOST`). Start/stop one
without affecting the others. Service config (nginx, supervisord, …) lives in
each template's **`configs/`** folder, mirroring the stack's own layout.

## How routing works

PHP is served by a shared FPM runtime (folder = vhost). Compiled/runtime apps
each run as their own container, so they get a hostname a different way:

```
dnsmasq (*.test -> 127.0.0.1)
        │
   nginx-proxy  (:80, watches Docker for VIRTUAL_HOST)
        ├─ svc-template-go.test    -> go container :8080     (exact match wins)
        ├─ web-template-react.test -> react container :5173
        └─ *.test (else)           -> PHP mass-vhost nginx (all www/ folders)
```

Any container that sets `VIRTUAL_HOST=<name>.test` (+ `VIRTUAL_PORT`) and joins
`lds-network` is routed automatically the moment it starts. That's the only
contract — it works for ANY language or framework, not just these four.

## Usage

```bash
# 1) Bring up the routing backbone once (proxy + dnsmasq):
../scripts/run/up.sh proxy            # Windows cmd: ..\scripts\run\up.bat proxy

# 2) Start any template:
cd svc-template-go
docker compose up -d                  # -> http://svc-template-go.test
```

## Turn a template into a real project

1. Copy the folder into the matching place, e.g. `D:\projects\Golang\orders`.
2. Set `APP_HOST` (e.g. `orders.test`) in a `.env` next to the compose file.
3. `docker compose up -d` → `http://orders.test`.

You **never edit `local-dev-stack`'s own files** and you **don't add a
`public/`/index page** (that's only for plain PHP in `www/`). The hostname works
automatically — `dns` wildcard-resolves `*.test` and `proxy` auto-discovers the
container — as long as `init.sh` ran once and `up.sh proxy` is up.

To add routing to a project you ALREADY have, you don't need a template —
just add to its compose service:

```yaml
    environment:
      VIRTUAL_HOST: orders.test
      VIRTUAL_PORT: "8080"      # the port your app listens on
    networks: [lds-network]
networks:
  lds-network:
    external: true
```

## Backing services (from any container on lds-network)

`mysql:3306` · `postgres:5432` · `redis:6379` · `memcached:11211` ·
`kafka-broker:9092` · `schema-registry:8080` · `connect-debezium:8083` ·
`connect-generic:8083`
