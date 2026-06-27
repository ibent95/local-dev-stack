#!/usr/bin/env bash
# Bring up one or more profiles.  ./scripts/run/up.sh mysql redis   |   up.sh all
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

[ -f .env ] || { echo "No .env — creating from .env.example"; cp .env.example .env; }

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
  for p in proxy php mysql postgres mongo redis memcached kafka phpcacheadmin dbgate soketi centrifugo mqtt drawdb hop superset semgrep; do
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
case "$https" in
  true|TRUE|True|1|yes|on|y)
    case " ${profiles[*]} " in
      *" proxy "*|*" php "*|*" all "*)
        [ -s configs/proxy/certs/test.crt ] || "$ROOT/scripts/run/certs.sh" || true
        compose_files+=(-f docker-compose.https.yml)
        echo "HTTPS overlay enabled (proxy TLS on :${WEB_HTTPS_PORT:-443})." ;;
      *) echo "LDS_ENABLE_HTTPS=true but no proxy/php profile selected — HTTPS overlay skipped." ;;
    esac ;;
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

# Seed DBGate connections into its volume BEFORE it starts (fresh setups only;
# skips if you already have connections). Keeps the stack DBs auto-listed.
case " ${profiles[*]} " in
  *" dbgate "*|*" all "*) sub "dbgate-seed"; "$ROOT/scripts/run/dbgate-seed.sh" || true; subdone ;;
esac

sub "compose up -d (pull + start containers): ${profiles[*]}"
# --remove-orphans clears containers left behind by renamed/removed services
# (profile-gated services still in the file are kept). If `up` fails (e.g. an
# image pull errored), STOP — don't fall through to mongo-init/kafka-topics,
# which would wait on containers that never started.
if ! docker compose "${compose_files[@]}" "${args[@]}" up -d --remove-orphans; then
  echo "compose up failed — aborting (check the pull/error above)."
  docker compose "${compose_files[@]}" "${args[@]}" ps
  exit 1
fi
docker compose "${compose_files[@]}" "${args[@]}" ps
subdone

# Ensure the MySQL app database + user (DHI mysql doesn't auto-create them).
case " ${profiles[*]} " in
  *" mysql "*|*" all "*) sub "mysql-init"; "$ROOT/scripts/run/mysql-init.sh" || true; subdone ;;
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
