#!/usr/bin/env bash
# Ensure the default MySQL database/user exist and optionally provision extra
# tool databases/users from MYSQL_INIT_SPECS.
# The DHI mysql image's entrypoint (unlike the official image) does NOT honor
# MYSQL_DATABASE / MYSQL_USER / /docker-entrypoint-initdb.d — it only sets up
# the datadir + root password — so we create them here. Idempotent; auto-run by
# `lds up` for the mysql/all profile.
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
C="lds-mysql"
RP="${MYSQL_ROOT_PASSWORD:-root}"
DB="${MYSQL_DATABASE:-app}"
U="${MYSQL_USER:-app}"
P="${MYSQL_PASSWORD:-app}"
SPECS="${MYSQL_INIT_SPECS:-}"

sql_lit() { printf "%s" "$1" | sed "s/'/''/g"; }
sql_ident() { printf "%s" "$1" | sed 's/`/``/g'; }

ensure_db_user() {
  local db="$1" u="$2" p="$3"
  local db_i u_l p_l
  db_i="$(sql_ident "$db")"
  u_l="$(sql_lit "$u")"
  p_l="$(sql_lit "$p")"
  echo "Ensuring MySQL database '$db' + user '$u'…"
  docker exec "$C" mysql -uroot -p"$RP" -e \
    "CREATE DATABASE IF NOT EXISTS \`$db_i\`;
     CREATE USER IF NOT EXISTS '$u_l'@'%' IDENTIFIED BY '$p_l';
     ALTER USER '$u_l'@'%' IDENTIFIED BY '$p_l';
     GRANT ALL PRIVILEGES ON \`$db_i\`.* TO '$u_l'@'%';
     FLUSH PRIVILEGES;" 2>&1 | grep -v "Using a password" || true
}

# Wait for mysql to accept the root login.
for i in $(seq 1 30); do
  docker exec "$C" mysql -uroot -p"$RP" -e "SELECT 1" >/dev/null 2>&1 && break
  [ "$i" = "30" ] && { echo "mysql not reachable in '$C' — is the mysql profile up?"; exit 1; }
  sleep 2
done

ensure_db_user "$DB" "$U" "$P"

# Extra tool db/user specs (comma-separated `db:user:password`), e.g.:
#   MYSQL_INIT_SPECS=tooldb:tooluser:toolpass,otherdb:otheruser:otherpass
IFS=',' read -ra init_specs <<< "$SPECS"
for spec in "${init_specs[@]}"; do
  spec="$(printf '%s' "$spec" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -z "$spec" ] && continue
  dbx="${spec%%:*}"
  rem="${spec#*:}"
  ux="${rem%%:*}"
  px="${rem#*:}"
  if [ "$rem" = "$spec" ] || [ "$px" = "$rem" ] || [ -z "$dbx" ] || [ -z "$ux" ] || [ -z "$px" ]; then
    echo "Skipping invalid MYSQL_INIT_SPECS entry '$spec' (expected db:user:password)."
    continue
  fi
  ensure_db_user "$dbx" "$ux" "$px"
done

# Apply seed/schema SQL into $DB. DHI mysql ignores /docker-entrypoint-initdb.d,
# so we feed configs/mysql/init/*.sql ourselves (idempotent files → safe to re-run).
for f in configs/mysql/init/*.sql; do
  [ -e "$f" ] || continue
  echo "  applying $(basename "$f")…"
  docker exec -i "$C" mysql -uroot -p"$RP" "$DB" < "$f" 2>&1 | grep -v "Using a password" || true
done

echo "MySQL ready (database '$DB', user '$U')."
