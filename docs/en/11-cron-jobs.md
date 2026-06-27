# 11 · Scheduled jobs (cron)

LDS runs scheduled work with **[supercronic](https://github.com/aptible/supercronic)** —
a container-friendly cron: runs as non-root, reads a standard `crontab`, and logs
every run to **stdout** (so `docker logs` / `lds app logs` just shows it). It's a
single foreground process, so no system `cron` daemon and no `supervisord` are
required just to schedule.

There are **two ways** to schedule, depending on whether the job is standalone or
part of a PHP app.

---

## A. Standalone cron job — any technology (recommended)

A dedicated container that does one scheduled task. Works for **any language** —
the job is just a command supercronic runs on a schedule.

```bash
lds new cron-python my-job   # or cron-shell / cron-node / cron-go / cron-php
cd <that dir>
lds app start                # build & run
lds app logs                 # watch each scheduled run
lds app stop
```

`cron` is a first-class role (like `svc`/`web`): `lds new cron-<tech> <name>`
scaffolds `cron-template-<tech>` into that tech's `*_PROJECTS_PATH` (so
`cron-python` lands in `PYTHON_PROJECTS_PATH` alongside your other Python
projects; `cron-shell`, having no language home, uses `JOBS_PROJECTS_PATH`).
Each has:
- **`crontab`** — the schedule, e.g. `*/5 * * * * <run job>`
- **`job.<ext>`** — the task in that language (edit this)
- **`Dockerfile`** — the language base + supercronic (Go builds a binary first)
- **`docker-compose.yml`** — joins `lds-network`, **no web port** (a worker)

It's on `lds-network`, so the job reaches backing services by name:
`mysql:3306`, `postgres:5432`, `mongo:27017`, `redis:6379`, `kafka-broker:9092`.

### Available cron techs (and how each runs)
Pick the role-tech; the template wires the base image + crontab command for you:

| Language | Dockerfile base | crontab line |
|---|---|---|
| Shell | `alpine` (default) | `*/5 * * * * /app/job.sh` |
| Python | `python:3.12-slim` | `*/5 * * * * python /app/job.py` |
| Node | `node:22-alpine` | `*/5 * * * * node /app/job.js` |
| PHP | `php:8.4-cli` | `*/5 * * * * php /app/job.php` |
| Go (compiled) | multi-stage → binary on `alpine` | `*/5 * * * * /app/job` |

Interpreted runtimes (Python/Node/PHP) just run the script. Compiled ones
(Go/Rust/Java) build the artifact in a build stage, then supercronic runs the
binary (so it's not recompiled every tick).

> **Real example:** `svc-setting-access-log-retention-python` — a native-Python
> purge that deletes `access_log` rows older than `RETENTION_DAYS` via PyMySQL,
> scheduled by supercronic.

### Two images: local vs cloud (deploy)
Each cron project has **two Dockerfiles**:
- **`Dockerfile`** — the **cloud/default** image (what Kubernetes/Fleet builds).
  Self-contained: `COPY`s source + the vendored supercronic binary.
- **`LDS.Dockerfile`** — the **local** image used by `lds`/docker-compose
  (`build.dockerfile: LDS.Dockerfile`); bind-mounts source for live edits. It
  gets supercronic from the `lds/*` dev base (all bases now ship it), so it does
  **not** vendor the binary — except `cron-shell`, whose Alpine base has none.

**No network at build:** supercronic is **vendored for the cloud image** —
`lds new cron-*` copies `assets/supersonic/<ver>/supercronic-linux-amd64` into
the project as `bin/supercronic`, and the cloud `Dockerfile` `COPY`s it (its
official base has no supercronic). So the cloud build works offline / behind a
firewall (commit `bin/supercronic` to the repo).

---

## B. Inside a PHP app container

The `lds/php` base ships supercronic as a supervisord program, **off by default**.
Turn it on per project:

1. Provide a crontab at `/etc/supervisor/crontab` (COPY it in the project's
   Dockerfile, or mount it).
2. Set `ENABLE_CRON=true` in the service's environment.

supervisord then runs it alongside php-fpm + nginx. The shared mass-vhost `php`
container leaves it off.

**Laravel / Symfony** keep their **own** scheduler programs (e.g. Laravel's
`worker.conf` with `[program:scheduler]`, toggled by `ENABLE_SCHEDULER`) rather
than the generic `[program:cron]`.

---

## Other base images (Go / Rust / Node / Python / Java)

Those dev bases run a **single** foreground process (air, watchfiles, …) — they
**don't** bundle supervisord or supercronic. For scheduled work in those stacks,
use **approach A** (a standalone cron container). One job = one container is
cleaner, isolated, and mirrors a Kubernetes CronJob.

---

## crontab quick reference

```
# ┌ minute (0-59)
# │ ┌ hour (0-23)
# │ │ ┌ day of month (1-31)
# │ │ │ ┌ month (1-12)
# │ │ │ │ ┌ day of week (0-6, Sun=0)
# │ │ │ │ │
  * * * * *  command
```
Examples: `*/5 * * * *` every 5 min · `0 2 * * *` daily 02:00 · `0 * * * *` hourly.
Times use the container `TZ`. supercronic logs each run; a bad crontab makes it
exit non-zero (fail-fast).
