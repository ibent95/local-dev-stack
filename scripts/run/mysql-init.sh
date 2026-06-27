#!/usr/bin/env bash
# Ensure the `app` database + `app` user exist. The DHI mysql image's entrypoint
# (unlike the official image) does NOT honor MYSQL_DATABASE / MYSQL_USER /
# /docker-entrypoint-initdb.d — it only sets up the datadir + root password — so
# we create them here. Idempotent; auto-run by `lds up` for the mysql/all profile.
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

# Wait for mysql to accept the root login.
for i in $(seq 1 30); do
  docker exec "$C" mysql -uroot -p"$RP" -e "SELECT 1" >/dev/null 2>&1 && break
  [ "$i" = "30" ] && { echo "mysql not reachable in '$C' — is the mysql profile up?"; exit 1; }
  sleep 2
done

echo "Ensuring MySQL database '$DB' + user '$U'…"
docker exec "$C" mysql -uroot -p"$RP" -e \
  "CREATE DATABASE IF NOT EXISTS $DB;
   CREATE USER IF NOT EXISTS '$U'@'%' IDENTIFIED BY '$P';
   GRANT ALL PRIVILEGES ON $DB.* TO '$U'@'%';
   FLUSH PRIVILEGES;" 2>&1 | grep -v "Using a password" || true

# Apply seed/schema SQL into $DB. DHI mysql ignores /docker-entrypoint-initdb.d,
# so we feed configs/mysql/init/*.sql ourselves (idempotent files → safe to re-run).
for f in configs/mysql/init/*.sql; do
  [ -e "$f" ] || continue
  echo "  applying $(basename "$f")…"
  docker exec -i "$C" mysql -uroot -p"$RP" "$DB" < "$f" 2>&1 | grep -v "Using a password" || true
done

echo "MySQL ready (database '$DB', user '$U')."
