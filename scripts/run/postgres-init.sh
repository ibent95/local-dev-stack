#!/usr/bin/env bash
# Ensure the default Postgres database/user exist and optionally provision extra
# tool databases/users from POSTGRES_INIT_SPECS (db:user:password entries).
# Idempotent; auto-run by `lds up` for the postgres/all profile.
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

C="lds-postgres"
BOOT_U="${POSTGRES_USER:-app}"
BOOT_P="${POSTGRES_PASSWORD:-app}"
DB="${POSTGRES_DB:-app}"
U="${POSTGRES_USER:-app}"
P="${POSTGRES_PASSWORD:-app}"
SPECS="${POSTGRES_INIT_SPECS:-}"

sql_lit() { printf "%s" "$1" | sed "s/'/''/g"; }
sql_ident() { printf "%s" "$1" | sed 's/"/""/g'; }
q() {
  docker exec -e PGPASSWORD="$BOOT_P" "$C" psql -U "$BOOT_U" -d postgres -tA -c "$1"
}
x() {
  docker exec -e PGPASSWORD="$BOOT_P" "$C" psql -v ON_ERROR_STOP=1 -U "$BOOT_U" -d postgres -c "$1" >/dev/null
}

ensure_db_user() {
  local db="$1" u="$2" p="$3"
  local db_i u_i db_l u_l p_l
  db_i="$(sql_ident "$db")"; u_i="$(sql_ident "$u")"
  db_l="$(sql_lit "$db")"; u_l="$(sql_lit "$u")"; p_l="$(sql_lit "$p")"

  if [ "$(q "SELECT 1 FROM pg_roles WHERE rolname='$u_l' LIMIT 1;")" != "1" ]; then
    echo "Creating Postgres role '$u'…"
    x "CREATE ROLE \"$u_i\" LOGIN PASSWORD '$p_l';"
  else
    x "ALTER ROLE \"$u_i\" WITH LOGIN PASSWORD '$p_l';"
  fi

  if [ "$(q "SELECT 1 FROM pg_database WHERE datname='$db_l' LIMIT 1;")" != "1" ]; then
    echo "Creating Postgres database '$db' (owner '$u')…"
    x "CREATE DATABASE \"$db_i\" OWNER \"$u_i\";"
  fi

  x "GRANT CONNECT ON DATABASE \"$db_i\" TO \"$u_i\";"
  docker exec -e PGPASSWORD="$BOOT_P" "$C" psql -v ON_ERROR_STOP=1 -U "$BOOT_U" -d "$db" -c \
    "GRANT USAGE, CREATE ON SCHEMA public TO \"$u_i\";
     ALTER SCHEMA public OWNER TO \"$u_i\";
     GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"$u_i\";
     GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"$u_i\";
     ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"$u_i\";
     ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO \"$u_i\";" >/dev/null

  echo "Postgres database '$db' + user '$u' ready."
}

# Wait for postgres to accept connections.
for i in $(seq 1 30); do
  docker exec -e PGPASSWORD="$BOOT_P" "$C" psql -U "$BOOT_U" -d postgres -tAc "SELECT 1" >/dev/null 2>&1 && break
  [ "$i" = "30" ] && { echo "postgres not reachable in '$C' — is the postgres profile up?"; exit 1; }
  sleep 2
done

ensure_db_user "$DB" "$U" "$P"

# Extra tool db/user specs (comma-separated `db:user:password`), e.g.:
#   POSTGRES_INIT_SPECS=insighttrack:insighttrack:insighttrack
# Trim whitespace and skip if empty.
SPECS="$(printf '%s' "$SPECS" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
[ -z "$SPECS" ] && exit 0
IFS=',' read -ra init_specs <<< "$SPECS"
for spec in "${init_specs[@]}"; do
  spec="$(printf '%s' "$spec" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -z "$spec" ] && continue
  dbx="${spec%%:*}"
  rem="${spec#*:}"
  ux="${rem%%:*}"
  px="${rem#*:}"
  if [ "$rem" = "$spec" ] || [ "$px" = "$rem" ] || [ -z "$dbx" ] || [ -z "$ux" ] || [ -z "$px" ]; then
    echo "Skipping invalid POSTGRES_INIT_SPECS entry '$spec' (expected db:user:password)."
    continue
  fi
  ensure_db_user "$dbx" "$ux" "$px"
done

