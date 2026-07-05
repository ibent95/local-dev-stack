#!/usr/bin/env bash
# Ensure Postgres has the InsightTrack database/user. Reuses postgres-init by
# injecting the InsightTrack spec into POSTGRES_INIT_SPECS for this run.
# Idempotent; auto-run by `lds up` for insighttrack/all.
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [ -f .env ]; then
  while IFS='=' read -r k v; do
    case "$k" in ''|'#'*) continue ;; esac
    [ -z "${!k:-}" ] && export "$k=$v"
  done < .env
fi

db="${INSIGHTTRACK_POSTGRES_DB:-app}"
u="${INSIGHTTRACK_POSTGRES_USER:-app}"
p="${INSIGHTTRACK_POSTGRES_PASSWORD:-app}"
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
