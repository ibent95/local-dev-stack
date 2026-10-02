#!/usr/bin/env bash
# Bring up one or more profiles.  ./scripts/run/up.sh mysql redis   |   up.sh all
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# --- --rebuild flag: add --build to docker compose up ------------------------
REBUILD=0
args_raw=()
for a in "$@"; do
  case "$a" in
    --rebuild) REBUILD=1 ;;
    *) args_raw+=("$a") ;;
  esac
done
set -- "${args_raw[@]}"

[ -f .env ] || { echo "No .env — creating from .env.example"; cp .env.example .env; }

# Keep .env in sync with .env.example (keeps your values; adds missing vars).
"$ROOT/scripts/run/env-sync.sh" --quiet || true

NET="${NETWORK_NAME:-lds-network}"
docker network inspect "$NET" >/dev/null 2>&1 || {
  echo "Creating shared network '$NET'"; docker network create "$NET" >/dev/null;
}

# Profiles to start: explicit args win. With no args, build the default run-set
# from the per-service toggles in .env (LDS_ENABLE_<PROFILE>=true|false), else
# "all". We read .env directly here (rather than exporting COMPOSE_PROFILES) so
# `up <profile>` stays scoped to exactly what you ask for and isn't silently
# unioned with the defaults.
if [ $# -gt 0 ]; then
  profiles=("$@")
else
  profiles=()
  # Canonical profile order; each maps to LDS_ENABLE_<UPPER>=true in .env.
  for p in proxy php mysql mariadb mssql oracle postgres mongo redis valkey memcached kafka phpcacheadmin dbx soketi centrifugo mqtt drawdb hop superset semgrep zap trivy crg vaultwarden mail penpot instatic analytics tasks wiki openwa headlessx playwright erpnext rustfs duckdb trino; do
    var="LDS_ENABLE_$(printf '%s' "$p" | tr '[:lower:]' '[:upper:]')"
    val="$(grep -E "^[[:space:]]*${var}=" .env 2>/dev/null | tail -1 | cut -d= -f2- | sed 's/#.*//' | tr -d '[:space:]\r')"
    case "$val" in
      true|TRUE|True|1|yes|on|y) profiles+=("$p") ;;
    esac
  done
  [ ${#profiles[@]} -eq 0 ] && profiles=("all")
  echo "No profiles given — using enabled toggles (LDS_ENABLE_*): ${profiles[*]}"
fi
args=(); for p in "${profiles[@]}"; do args+=(--profile "$p"); done

# HTTPS opt-in: when LDS_ENABLE_HTTPS=true AND a proxy/php profile is in the set,
# layer the TLS overlay (docker-compose.https.yml) onto the base file and make
# sure a dev cert exists. Off / no-proxy → plain http only (base file alone).
compose_files=(-f docker-compose.yml)
https="$(grep -E '^[[:space:]]*LDS_ENABLE_HTTPS=' .env 2>/dev/null | tail -1 | cut -d= -f2- | sed 's/#.*//' | tr -d '[:space:]\r')"
HTTPS_ACTIVE=0
case "$https" in
  true|TRUE|True|1|yes|on|y)
    case " ${profiles[*]} " in
      *" proxy "*|*" php "*|*" all "*)
        [ -s configs/proxy/certs/test.crt ] || "$ROOT/scripts/run/certs.sh" || true
        compose_files+=(-f docker-compose.https.yml)
        HTTPS_ACTIVE=1
        echo "HTTPS overlay enabled (proxy TLS on :${WEB_HTTPS_PORT:-443})." ;;
      *) echo "LDS_ENABLE_HTTPS=true but no proxy/php profile selected — HTTPS overlay skipped." ;;
    esac ;;
esac

# Keep public-facing Penpot URI in sync with the active edge scheme to avoid
# mixed-content/CORS-looking browser failures when HTTPS is enabled.
case " ${profiles[*]} " in
  *" penpot "*|*" all "*)
    penpot_host="$(grep -E '^[[:space:]]*PENPOT_HOST=' .env 2>/dev/null | tail -1 | cut -d= -f2- | sed 's/#.*//' | tr -d '[:space:]\r')"
    [ -n "$penpot_host" ] || penpot_host="penpot.test"
    penpot_uri="$(grep -E '^[[:space:]]*PENPOT_PUBLIC_URI=' .env 2>/dev/null | tail -1 | cut -d= -f2- | sed 's/#.*//' | tr -d '\r')"
    [ -n "$penpot_uri" ] || penpot_uri="http://${penpot_host}"
    scheme="http"; [ "$HTTPS_ACTIVE" -eq 1 ] && scheme="https"
    if printf '%s' "$penpot_uri" | grep -Eq '^https?://'; then
      penpot_uri="$(printf '%s' "$penpot_uri" | sed -E "s#^https?://#${scheme}://#")"
    else
      penpot_uri="${scheme}://${penpot_host}"
    fi
    export PENPOT_PUBLIC_URI="$penpot_uri"
    echo "Penpot public URI resolved to ${PENPOT_PUBLIC_URI} (scheme: ${scheme})."
    ;;
esac

# --- sub-step banners (subordinate to start's [n/5] banners) ---------------
SUB=""
sub()     { SUB="$1"; printf '\n-------- up: %s --------\n' "$1"; }
subdone() { printf -- '-------- up: %s: done --------\n' "$SUB"; }

# The php/all profile needs the lds/php base image — build it once if missing.
case " ${profiles[*]} " in
  *" php "*|*" all "*)
    if ! docker image inspect "lds/php:${PHP_VERSION:-8.4}" >/dev/null 2>&1; then
      sub "build lds/php base (first run)"
      ( cd "$ROOT" && docker buildx bake -f docker-bake.hcl --load php )
      subdone
    fi ;;
esac

# The Semgrep + Trivy + Playwright + CRG viewers use lds/nginx — build it once if missing.
case " ${profiles[*]} " in
  *" semgrep "*|*" trivy "*|*" playwright "*|*" crg "*|*" all "*)
    if ! docker image inspect "lds/nginx:${NGINX_VERSION:-1.27}" >/dev/null 2>&1; then
      sub "build lds/nginx base (first run)"
      ( cd "$ROOT" && docker buildx bake -f docker-bake.hcl --load nginx )
      subdone
    fi ;;
esac

# Node-based apps (analytics, tasks, wiki) need lds/node-dev.
case " ${profiles[*]} " in
  *" analytics "*|*" tasks "*|*" wiki "*|*" all "*)
    if ! docker image inspect "lds/node-dev:${NODE_VERSION:-26.3}" >/dev/null 2>&1; then
      sub "build lds/node-dev base (first run)"
      ( cd "$ROOT" && docker buildx bake -f docker-bake.hcl --load node-dev )
      subdone
    fi ;;
esac

# DuckDB service uses lds/duckdev (DHI alpine-base + DuckDB CLI binary).
case " ${profiles[*]} " in
  *" duckdb "*|*" all "*)
    if ! docker image inspect "lds/duckdev:${DUCKDB_VERSION:-1.2.0}" >/dev/null 2>&1; then
      sub "build lds/duckdev base (first run)"
      ( cd "$ROOT" && docker buildx bake -f docker-bake.hcl --load duckdev )
      subdone
    fi ;;
esac

# The code-review-graph scanner image (configs/crg) — build it once so the first
# `lds tools crg` run has no build delay (upstream ships no official image).
case " ${profiles[*]} " in
  *" crg "*|*" all "*)
    if ! docker image inspect "lds/crg:${CRG_VERSION:-2.3.7}" >/dev/null 2>&1; then
      sub "build lds/crg scanner (first use)"
      docker build -q -t "lds/crg:${CRG_VERSION:-2.3.7}" "$ROOT/configs/crg" >/dev/null
      subdone
    fi ;;
esac

# Seed sample Parquet/CSV/JSON data for DuckDB and Trino. Runs before compose
# up so the files are available when the containers start. Skips if files exist.
case " ${profiles[*]} " in
  *" duckdb "*|*" trino "*|*" all "*) sub "seed-data"; "$ROOT/scripts/run/seed-data.sh" || true; subdone ;;
esac

# Ensure the HeadlessX source checkout exists (build context for the headlessx-*
# services). Clones on first run, fast-forwards afterwards. Runs before compose
# up so the build contexts are valid.
case " ${profiles[*]} " in
  *" headlessx "*|*" all "*) sub "headlessx-init"; "$ROOT/scripts/run/headlessx-init.sh" || true; subdone ;;
esac



up_flags=(-d --remove-orphans)
if [ "$REBUILD" -eq 1 ]; then
  up_flags+=(--build)
  sub "compose up -d --build (rebuild + start containers): ${profiles[*]}"
else
  sub "compose up -d (pull + start containers): ${profiles[*]}"
fi
# --remove-orphans clears containers left behind by renamed/removed services
# (profile-gated services still in the file are kept). If `up` fails (e.g. an
# image pull errored), STOP — don't fall through to mongo-init/kafka-topics,
# which would wait on containers that never started.
if ! docker compose "${compose_files[@]}" "${args[@]}" up "${up_flags[@]}"; then
  echo "compose up failed — aborting (check the pull/error above)."
  docker compose "${compose_files[@]}" "${args[@]}" ps
  exit 1
fi
docker compose "${compose_files[@]}" "${args[@]}" ps
subdone

# Seed DBX connections AFTER it is up (the seed goes through DBX's Web API, so
# the container must be answering; fresh setups only — skips if you already
# added connections). Keeps the stack DBs auto-listed.
case " ${profiles[*]} " in
  *" dbx "*|*" all "*) sub "dbx-seed"; "$ROOT/scripts/run/dbx-seed.sh" || true; subdone ;;
esac

# LDS app DBs are now created inline by the postgres service (entrypoint wrapper).
# The mysql-init.sh and postgres-init.sh scripts are kept for manual use:
#   lds exec postgres /postgres-init.sh
#   lds exec mysql /mysql-init.sh
# Remove the old auto-run calls — the DB services self-initialize on startup.

# Ensure the LDS Analytics DB/user spec exists.
case " ${profiles[*]} " in
  *" analytics "*|*" all "*) sub "analytics-init"; "$ROOT/scripts/run/analytics-init.sh" || true; subdone ;;
esac

# Ensure the LDS Tasks DB/user spec exists.
case " ${profiles[*]} " in
  *" tasks "*|*" all "*) sub "tasks-init"; "$ROOT/scripts/run/tasks-init.sh" || true; subdone ;;
esac

# Ensure the LDS Wiki DB/user spec exists.
case " ${profiles[*]} " in
  *" wiki "*|*" all "*) sub "wiki-init"; "$ROOT/scripts/run/wiki-init.sh" || true; subdone ;;
esac

# Ensure the HeadlessX DB/user exists (postgres may predate the spec addition).
case " ${profiles[*]} " in
  *" headlessx "*|*" all "*) sub "headlessx-db-init"; "$ROOT/scripts/run/headlessx-db-init.sh" || true; subdone ;;
esac

# Ensure the Hive Metastore DB/user exists. The metastore container's schematool
# retries while waiting for this DB; without it schematool fails (the DB is never
# created, since postgres-init no longer auto-runs). Runs before trino connects.
case " ${profiles[*]} " in
  *" trino "*|*" all "*) sub "hive-metastore-init"; "$ROOT/scripts/run/hive-metastore-init.sh" || true; subdone ;;
esac

# Initiate the Mongo replica set + users (single-node RS for CDC).
case " ${profiles[*]} " in
  *" mongo "*|*" all "*) sub "mongo-init"; "$ROOT/scripts/run/mongo-init.sh" || true; subdone ;;
esac

# Provision Kafka topics (replaces the old one-shot kafka-init service).
case " ${profiles[*]} " in
  *" kafka "*|*" all "*) sub "kafka-topics"; "$ROOT/scripts/run/kafka-topics.sh"; subdone ;;
esac

# Pre-pull the Semgrep scanner so it ships with the profile. The scanner is a
# one-shot in its OWN `semgrep-scan` profile (so `up` never starts it / leaves an
# Exited container), but we fetch its pinned image here so the first
# `lds tools semgrep` runs without a surprise pull. Best-effort (slow/offline links).
case " ${profiles[*]} " in
  *" semgrep "*|*" all "*)
    sub "semgrep-scan: pre-pull scanner image"
    docker compose "${compose_files[@]}" --profile semgrep-scan pull semgrep-scan || true
    subdone ;;
esac

# Pre-pull the Trivy scanner (same rationale as semgrep-scan above).
case " ${profiles[*]} " in
  *" trivy "*|*" all "*)
    sub "trivy-scan: pre-pull scanner image"
    docker compose "${compose_files[@]}" --profile trivy-scan pull trivy-scan || true
    subdone ;;
esac

# Register Hop projects (folder-per-project) into hop-config.json via hop-conf.
case " ${profiles[*]} " in
  *" hop "*|*" all "*) sub "hop-register"; "$ROOT/scripts/run/hop-register.sh" || true; subdone ;;
esac
