# 05 · Base images

The PHP extension set and each language's dev tooling are built **once** into
shared `lds/*` base images (sources in `base-images/`), then reused by the stack
and every template — so heavy installs (PECL, cargo-watch, …) happen once.

All bases build **FROM Docker Hardened Images (DHI)** under
`${DHI_REGISTRY:-dhi.io}`, using the `-dev` flavor (ships a shell + apt). DHI
defaults to a non-root user, so each Dockerfile does `USER root` for its build +
runtime steps.

| Image | FROM (DHI) | Contents |
|-------|------------|----------|
| `lds/php` | `alpine-base:3.24-dev` ¹ | php-fpm + extensions + composer **+ nginx + supervisor**, bakes the global `configs/php-app/*` (the ONE PHP base; supervisord runs php-fpm + nginx) |
| `lds/go-dev` | `golang:1.26-alpine3.24-dev` | Go + air |
| `lds/rust-dev` | `rust:1.96-alpine3.24-dev` | Rust + cargo-watch |
| `lds/node-dev` | `node:26.3-alpine3.24-dev` | pinned Node |
| `lds/python-dev` | `python:3.14-alpine3.24-dev` | Python + watchfiles |
| `lds/java-dev` | `eclipse-temurin:25-jdk-alpine3.24-dev` ² | Maven + JDK |

¹ **PHP is the DHI exception.** The `dhi.io/php` images are split — a minimal
`-dev` build with **no php-fpm** and **no `docker-php-ext-*` helpers**, plus a
hardened `-fpm` runtime with **no shell/apk** — so neither can host the fat
single container. Instead `lds/php` builds FROM `dhi.io/alpine-base:3.24-dev`
and installs php-fpm + extensions + nginx + supervisor from Alpine's repos
(`php` = `php84`). The DHI Alpine repo has no php, so the Dockerfile adds the
upstream Alpine `main`+`community` repos (same shape as debian-base pulling php
from Debian). `rdkafka`, `redis` and `memcached` ship as apk packages
(`php84-pecl-*`, which auto-enable their own conf.d ini); `apfd` (no apk package)
is compiled via **PECL** using a throwaway `.build-deps` toolchain that's
`apk del`'d afterward, so the final image ships no compiler. Alpine `apk` has no
init/postinst machinery, so
none of the `adm`/`www-data`/`invoke-rc.d` daemon-postinst issues Debian needs
worked around. Compat shims keep the official-image layout the configs/mounts
expect: `php-fpm84` (+ `php84`/`phpize84`/`php-config84`) on `$PATH`, the fpm
pool on `127.0.0.1:9000` as the `nginx` user, `/usr/local/etc/php/conf.d`
symlinked to `/etc/php84/conf.d`, and nginx's `conf.d` symlinked to `http.d`
(Alpine includes `server{}` blocks from `http.d`, not `conf.d`).

² DHI publishes no `maven:*` image, so `java-dev` installs Apache Maven from the
`archive.apache.org` binary dist — Alpine's busybox `wget` + gzip-aware `tar`
fetch and unpack it, so no apk install is needed.

> **musl note:** all language bases are on the Alpine (musl) flavor for one OS
> family across the stack. Trade-off: Python wheels and Node native addons must
> have musl builds, otherwise they compile from source in downstream templates.

- Versions are env-driven (`PHP_VERSION`, `GO_VERSION`, … in `.env`); each
  Dockerfile's `FROM` carries the per-language OS/flavor suffix. Set
  `DHI_REGISTRY` in `.env` to repoint the DHI namespace.
- Build / refresh: `./lds.sh build-bases` (`--force` to rebuild, `--push` to
  push to `$REGISTRY`). Orchestrated by `docker-bake.hcl` (`docker buildx bake`)
  — all six build in parallel from one definition.
- Built **once**; rebuild only when a version/dependency changes — not per
  template build, not per code change.
- Template **dev** stages `FROM lds/*`; **prod** stages stay on lean public
  images.

> The DB services (`mysql`/`postgres`/`redis`/`memcached`) and the dns image
> also come from DHI — see [13 · Profiles](13-profiles.md). DB services use the
> plain hardened **runtime** flavor (no `-dev`): `postgres`/`redis` on
> `*-alpine3.24`, `mysql`/`memcached` on `*-debian13` (DHI has no Alpine variant
> for those two). The dns image builds FROM `dhi.io/alpine-base:3.24-dev`.
