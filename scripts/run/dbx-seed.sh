#!/usr/bin/env bash
# Seed DBX's connection list through its Web API so the stack databases are
# auto-listed on a FRESH setup, and make sure the JDBC + LDAP Studio plugins
# are installed. The API only answers once the container is up, so this runs
# as a post-up hook from the `up` scripts. Three idempotent stages:
#
#   1. plugins  - JDBC plugin + LDAP Studio (io.dbx.ldap), each only when
#                 missing. First run downloads them from the official source
#                 (cached in data/dbx afterwards); failures are warnings so
#                 an offline start never blocks, the next `lds up dbx` retries.
#   2. DB seed  - MySQL + MariaDB + Postgres + Mongo + SQL Server + Oracle,
#                 ONLY when there are no saved connections at all, so it never
#                 clobbers ones you added.
#   3. LDAP seed - LLDAP + OpenLDAP connections (one file each), skipped per
#                 entry when a connection with that name already exists.
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

# --- Stage 1: plugins (JDBC + LDAP Studio), only when missing ---------------
# Matching is done on captured JSON (no `curl | grep`): with pipefail a
# grep -q that exits early can fail the pipeline and look like "not installed".
jdbc_status="$(curl -sf --max-time 15 "$URL/api/jdbc/plugin/status" 2>/dev/null || true)"
case "$jdbc_status" in
  *'"installed":true'*) ;;
  *)
    echo "DBX: installing JDBC plugin (first run downloads it)..."
    if curl -sf --max-time 300 -X POST "$URL/api/jdbc/plugin/install" >/dev/null 2>&1; then
      echo "DBX: JDBC plugin installed."
    else
      echo "DBX: JDBC plugin install FAILED — will retry on the next 'lds up dbx' (or install from dbx.test)."
    fi
    ;;
esac

plugins="$(curl -sf --max-time 15 "$URL/api/plugins" 2>/dev/null || true)"
case "$plugins" in
  *'"id":"io.dbx.ldap"'*) ;;
  *)
    echo "DBX: installing LDAP Studio plugin (first run downloads it)..."
    if curl -sf --max-time 300 -X POST -H 'Content-Type: application/json' \
         -d '{"repositoryId":"dbx-official","pluginId":"io.dbx.ldap"}' \
         "$URL/api/plugins/marketplace/install" >/dev/null 2>&1; then
      echo "DBX: LDAP Studio plugin installed."
    else
      echo "DBX: LDAP Studio install FAILED — will retry on the next 'lds up dbx' (or install from dbx.test)."
    fi
    ;;
esac

# --- Stage 2: DB connections, only when the list is empty -------------------
list="$(curl -sf --max-time 15 "$URL/api/connection/list" 2>/dev/null | tr -d '\r' || true)"
if [ -z "$list" ]; then
  echo "Could not read DBX's connection list — skipping seed."
  exit 0
fi
if [ "$list" = "[]" ]; then
  if curl -sf -X POST -H 'Content-Type: application/json' --data @"$SEED" \
       "$URL/api/connection/save" >/dev/null; then
    echo "Seeded DBX with MySQL + MariaDB + Postgres + Mongo + SQL Server + Oracle connections."
    list="$(curl -sf --max-time 15 "$URL/api/connection/list" 2>/dev/null | tr -d '\r' || true)"
  else
    echo "DBX connection seed FAILED — add them manually at $URL"
    exit 1
  fi
else
  echo "DBX already has connections — skipping DB seed."
fi

# --- Stage 3: LDAP connections, one seed file per directory -----------------
# Names are compared space-insensitively so the check is immune to JSON
# spacing; the seed file itself is the single source of the payload.
seed_ldap() {
  local name="$1" f="$2" name_flat list_flat
  [ -f "$f" ] || return 0
  name_flat="$(printf '%s' "$name" | tr -d ' ')"
  list_flat="$(printf '%s' "$list" | tr -d ' ')"
  case "$list_flat" in
    *"\"name\":\"$name_flat\""*)
      echo "DBX: $name connection already present — skipping."
      return 0
      ;;
  esac
  if curl -sf -X POST -H 'Content-Type: application/json' --data @"$f" \
       "$URL/api/connection/save" >/dev/null; then
    echo "DBX: seeded $name connection."
  else
    echo "DBX: seed FAILED for $name — add it manually at $URL"
    return 1
  fi
}

ldap_failed=0
seed_ldap "LLDAP (LDS)" "configs/dbx/connections.ldap-lldap.seed.json" || ldap_failed=1
seed_ldap "OpenLDAP (LDS)" "configs/dbx/connections.ldap-openldap.seed.json" || ldap_failed=1
[ "$ldap_failed" = "0" ] || exit 1
