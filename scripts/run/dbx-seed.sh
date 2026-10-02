#!/usr/bin/env bash
# Seed DBX's connection list through its Web API so the stack databases are
# auto-listed on a FRESH setup. The API only answers once the container is up,
# so this runs as a post-up hook from the `up` scripts. Idempotent: skips when
# connections already exist, so it never clobbers ones you added.
#
# Passwords below are the .env DEFAULTS (MSSQL_SA_PASSWORD / ORACLE_PASSWORD
# etc.). If you changed DB creds, edit them in the UI afterwards — add/edit is
# fully enabled (DBX_DISABLE_PASSWORD=1 keeps the API open too).
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

SEED="configs/dbx/connections.seed.json"
[ -f "$SEED" ] || { echo "No DBX seed file ($SEED) — skipping."; exit 0; }

# Container must be running (manual `lds db seed` skips when the profile is off).
if [ "$(docker inspect -f '{{.State.Running}}' lds-dbx 2>/dev/null)" != "true" ]; then
  echo "DBX container is not running — skipping connection seed. (Start it: lds up dbx)"
  exit 0
fi

# Host port comes from .env (DB_ADMIN_HOST_PORT, default 4501) so the script
# matches whatever the proxy/direct URL uses.
port="$(grep -E '^[[:space:]]*DB_ADMIN_HOST_PORT=' .env 2>/dev/null | tail -1 | cut -d= -f2- | sed 's/#.*//' | tr -d '[:space:]\r')"
port="${port:-4501}"
URL="http://localhost:${port}"

# compose up -d returns as soon as the container starts — wait for the listener.
ready=0
for _ in $(seq 1 30); do
  if curl -sf "$URL/api/auth/check" >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
if [ "$ready" != "1" ]; then
  echo "DBX did not answer on :$port within 30s — skipping connection seed."
  exit 0
fi

# Idempotent: only seed when there are no saved connections yet.
list="$(curl -sf "$URL/api/connection/list" | tr -d '[:space:]' || true)"
if [ -z "$list" ]; then
  echo "Could not read DBX's connection list — skipping seed."
  exit 0
fi
if [ "$list" != "[]" ]; then
  echo "DBX already has connections — leaving them as-is."
  exit 0
fi

if curl -sf -X POST -H 'Content-Type: application/json' --data @"$SEED" \
     "$URL/api/connection/save" >/dev/null; then
  echo "Seeded DBX with MySQL + MariaDB + Postgres + Mongo + SQL Server + Oracle connections."
else
  echo "DBX connection seed FAILED — add them manually at $URL"
  exit 1
fi
