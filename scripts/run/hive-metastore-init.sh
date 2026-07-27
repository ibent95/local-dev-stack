#!/usr/bin/env bash
# Ensure Postgres has the Hive Metastore database/user. Reuses postgres-init by
# injecting the metastore spec into POSTGRES_INIT_SPECS for this run.
# Idempotent; auto-run by `lds up` for trino/all.
#
# The Hive Metastore container's schematool retries while waiting for this DB to
# exist; without this step `schematool` fails forever (the DB is never created).
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [ -f .env ]; then
  while IFS='=' read -r k v; do
    case "$k" in ''|'#'*) continue ;; esac
    [ -z "${!k:-}" ] && export "$k=${v%$'\r'}"
  done < .env
fi

db="${HIVE_METASTORE_POSTGRES_DB:-lds_hive_metastore}"
u="${HIVE_METASTORE_POSTGRES_USER:-app}"
p="${HIVE_METASTORE_POSTGRES_PASSWORD:-app}"
spec="${db}:${u}:${p}"

merged="${POSTGRES_INIT_SPECS:-}"
if [ -n "$merged" ]; then
  merged="${merged},${spec}"
else
  merged="${spec}"
fi

# Deduplicate repeated specs while preserving order.
dedup=""
IFS=',' read -ra specs <<< "$merged"
for s in "${specs[@]}"; do
  s="$(printf '%s' "$s" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -z "$s" ] && continue
  case ",$dedup," in
    *",$s,"*) ;;
    *) dedup="${dedup:+$dedup,}$s" ;;
  esac
done

POSTGRES_INIT_SPECS="$dedup" "$ROOT/scripts/run/postgres-init.sh"
