#!/usr/bin/env bash
# Ensure Postgres has the LDS Tasks database/user. Reuses postgres-init by
# injecting the tasks spec into POSTGRES_INIT_SPECS for this run.
# Idempotent; auto-run by `lds up` for tasks/all.
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

db="${TASKS_POSTGRES_DB:-lds_tasks}"
u="${TASKS_POSTGRES_USER:-app}"
p="${TASKS_POSTGRES_PASSWORD:-app}"
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

# Wait for postgres to be ready before applying schema (DHI PGDATA may re-init on restart)
for i in $(seq 1 30); do
  docker exec -e PGPASSWORD="$p" lds-postgres psql -U "$u" -d "$db" -tAc "SELECT 1" >/dev/null 2>&1 && break
  sleep 2
done

# Apply the Drizzle table schema (idempotent — uses CREATE TABLE IF NOT EXISTS).
schema="$ROOT/configs/tasks/api/schema.sql"
if [ -f "$schema" ]; then
  echo "Applying Tasks DB schema to '$db'…"
  docker exec -i -e PGPASSWORD="$p" lds-postgres psql -v ON_ERROR_STOP=1 -U "$u" -d "$db" < "$schema" >/dev/null
fi
