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

<table>
<thead>
<tr>
<th>Template</th>
<th>Stack (web tech)</th>
<th>Hot reload</th>
<th>Default URL</th>
<th>Code</th>
</tr>
</thead>
<tbody>
<tr>
<td>`svc-template-go`</td>
<td>Go — `net/http` (native)</td>
<td>air</td>
<td>http://svc-template-go.test</td>
<td>included</td>
</tr>
<tr>
<td>`svc-template-node`</td>
<td>Node — `http` module (native)</td>
<td>tsx watch</td>
<td>http://svc-template-node.test</td>
<td>included</td>
</tr>
<tr>
<td>`svc-template-python`</td>
<td>Python — `http.server` (native)</td>
<td>watchfiles</td>
<td>http://svc-template-python.test</td>
<td>included</td>
</tr>
<tr>
<td>`svc-template-java`</td>
<td>Java — Servlet (native)</td>
<td>rebuild</td>
<td>http://svc-template-java.test</td>
<td>included</td>
</tr>
<tr>
<td>`svc-template-rust`</td>
<td>Rust — axum</td>
<td>cargo-watch</td>
<td>http://svc-template-rust.test</td>
<td>included</td>
</tr>
<tr>
<td>`svc-template-springboot`</td>
<td>Java — Spring Boot</td>
<td>devtools</td>
<td>http://svc-template-springboot.test</td>
<td>included</td>
</tr>
<tr>
<td>`svc-template-express`</td>
<td>Node — Express</td>
<td>tsx watch</td>
<td>http://svc-template-express.test</td>
<td>included</td>
</tr>
<tr>
<td>`svc-template-flask`</td>
<td>Python — Flask</td>
<td>flask debug</td>
<td>http://svc-template-flask.test</td>
<td>included</td>
</tr>
<tr>
<td>`svc-template-fastapi`</td>
<td>Python — FastAPI</td>
<td>uvicorn</td>
<td>http://svc-template-fastapi.test</td>
<td>included</td>
</tr>
<tr>
<td>`svc-template-django`</td>
<td>Python — Django + DRF</td>
<td>runserver</td>
<td>http://svc-template-django.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`svc-template-laravel`</td>
<td>PHP — Laravel (API-only)</td>
<td>php-fpm</td>
<td>http://svc-template-laravel.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`svc-template-symfony`</td>
<td>PHP — Symfony (skeleton)</td>
<td>php-fpm</td>
<td>http://svc-template-symfony.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`svc-template-slim`</td>
<td>PHP — Slim (micro)</td>
<td>php-fpm</td>
<td>http://svc-template-slim.test</td>
<td>included</td>
</tr>
<tr>
<td>`svc-template-webman`</td>
<td>PHP — Webman (workerman)</td>
<td>restart</td>
<td>http://svc-template-webman.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`svc-template-codeigniter`</td>
<td>PHP — CodeIgniter 4</td>
<td>php-fpm</td>
<td>http://svc-template-codeigniter.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`svc-template-cakephp`</td>
<td>PHP — CakePHP</td>
<td>php-fpm</td>
<td>http://svc-template-cakephp.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`svc-template-micronaut`</td>
<td>Java — Micronaut</td>
<td>mn:run</td>
<td>http://svc-template-micronaut.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`svc-template-quarkus`</td>
<td>Java — Quarkus</td>
<td>quarkus:dev</td>
<td>http://svc-template-quarkus.test</td>
<td>scaffolded</td>
</tr>
</tbody>
</table>

### Web apps (`web-`, serve a UI)

<table>
<thead>
<tr>
<th>Template</th>
<th>Stack (web tech)</th>
<th>Hot reload</th>
<th>Default URL</th>
<th>Code</th>
</tr>
</thead>
<tbody>
<tr>
<td>`web-template-go`</td>
<td>Go — `html/template` (native)</td>
<td>air</td>
<td>http://web-template-go.test</td>
<td>included</td>
</tr>
<tr>
<td>`web-template-node`</td>
<td>Node — `http` module (native)</td>
<td>tsx watch</td>
<td>http://web-template-node.test</td>
<td>included</td>
</tr>
<tr>
<td>`web-template-python`</td>
<td>Python — `http.server` (native)</td>
<td>watchfiles</td>
<td>http://web-template-python.test</td>
<td>included</td>
</tr>
<tr>
<td>`web-template-java`</td>
<td>Java — Servlet (native)</td>
<td>rebuild</td>
<td>http://web-template-java.test</td>
<td>included</td>
</tr>
<tr>
<td>`web-template-rust`</td>
<td>Rust — axum (HTML)</td>
<td>cargo-watch</td>
<td>http://web-template-rust.test</td>
<td>included</td>
</tr>
<tr>
<td>`web-template-springboot`</td>
<td>Java — Spring Boot + Thymeleaf</td>
<td>devtools</td>
<td>http://web-template-springboot.test</td>
<td>included</td>
</tr>
<tr>
<td>`web-template-express`</td>
<td>Node — Express (HTML)</td>
<td>tsx watch</td>
<td>http://web-template-express.test</td>
<td>included</td>
</tr>
<tr>
<td>`web-template-flask`</td>
<td>Python — Flask (HTML)</td>
<td>flask debug</td>
<td>http://web-template-flask.test</td>
<td>included</td>
</tr>
<tr>
<td>`web-template-fastapi`</td>
<td>Python — FastAPI (HTML)</td>
<td>uvicorn</td>
<td>http://web-template-fastapi.test</td>
<td>included</td>
</tr>
<tr>
<td>`web-template-django`</td>
<td>Python — Django (templates)</td>
<td>runserver</td>
<td>http://web-template-django.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`web-template-laravel`</td>
<td>PHP — Laravel (Blade + Vite)</td>
<td>php-fpm/vite</td>
<td>http://web-template-laravel.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`web-template-symfony`</td>
<td>PHP — Symfony (webapp/Twig)</td>
<td>php-fpm</td>
<td>http://web-template-symfony.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`web-template-slim`</td>
<td>PHP — Slim (HTML)</td>
<td>php-fpm</td>
<td>http://web-template-slim.test</td>
<td>included</td>
</tr>
<tr>
<td>`web-template-webman`</td>
<td>PHP — Webman (workerman)</td>
<td>restart</td>
<td>http://web-template-webman.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`web-template-codeigniter`</td>
<td>PHP — CodeIgniter 4 (views)</td>
<td>php-fpm</td>
<td>http://web-template-codeigniter.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`web-template-cakephp`</td>
<td>PHP — CakePHP (views)</td>
<td>php-fpm</td>
<td>http://web-template-cakephp.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`web-template-micronaut`</td>
<td>Java — Micronaut (views)</td>
<td>mn:run</td>
<td>http://web-template-micronaut.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`web-template-quarkus`</td>
<td>Java — Quarkus (Qute)</td>
<td>quarkus:dev</td>
<td>http://web-template-quarkus.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`web-template-vaadin`</td>
<td>Java — Vaadin (Flow, free core)</td>
<td>spring-boot</td>
<td>http://web-template-vaadin.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`web-template-angular`</td>
<td>Angular (SPA)</td>
<td>ng/HMR</td>
<td>http://web-template-angular.test</td>
<td>scaffolded</td>
</tr>
<tr>
<td>`web-template-react`</td>
<td>React + Vite (SPA)</td>
<td>vite HMR</td>
<td>http://web-template-react.test</td>
<td>scaffolded</td>
</tr>
</tbody>
</table>

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

<table>
<thead>
<tr>
<th>Template</th>
<th>Language</th>
<th>crontab runs</th>
</tr>
</thead>
<tbody>
<tr>
<td>`cron-template-shell`</td>
<td>POSIX shell</td>
<td>`/app/job.sh`</td>
</tr>
<tr>
<td>`cron-template-python`</td>
<td>Python</td>
<td>`python /app/job.py`</td>
</tr>
<tr>
<td>`cron-template-node`</td>
<td>Node.js</td>
<td>`node /app/job.js`</td>
</tr>
<tr>
<td>`cron-template-go`</td>
<td>Go (compiled → binary)</td>
<td>`/app/job`</td>
</tr>
<tr>
<td>`cron-template-php`</td>
<td>PHP (CLI)</td>
<td>`php /app/job.php`</td>
</tr>
</tbody>
</table>

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
