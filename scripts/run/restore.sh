#!/usr/bin/env bash
# Restore an `lds backup` folder back into the running stack.
#   lds restore [<folder>] [--only mysql,postgres,...] [--yes] [--keep-running]
#
# <folder> is a path or a name under data/backups (default: the newest one).
# THIS OVERWRITES CURRENT DATA. Each engine is restored from its own dump in
# the folder's manifest.tsv; engines missing from the folder are left alone.
#
# Notes per engine:
#   postgres  psql replays a pg_dumpall dump: DROP/CREATE DATABASE first, then
#             every schema. Errors (e.g. a database with live connections that
#             cannot be dropped) are reported but do not abort the rest.
#   mysql     mysqldump replay (CREATE DATABASE + USE per database).
#   mongo     mongorestore --drop (replaces collections in place).
#   redis     the RDB file replaces the volume's dump.rdb, so the container is
#             STOPPED, the file is copied in, then it is started again.
#   mssql     each .bak is restored WITH REPLACE.
#   volume/*  the tarball is unpacked over the named volume in place.
#
# Restore into a CLEAN stack when you can (`lds rm <profile>` first): that is
# the only way DROP DATABASE succeeds and the result is exactly the backup.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_ROOT="${BACKUP_DIR:-$ROOT/data/backups}"
SRC=""
ONLY=""
ASSUME_YES=0

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { printf "${BLUE}==>${NC} %s\n" "$*"; }
ok()   { printf "  ${GREEN}ok${NC}   %s\n" "$*"; }
skip() { printf "  ${YELLOW}skip${NC} %s\n" "$*"; }
bad()  { printf "  ${RED}fail${NC} %s\n" "$*"; }

usage() { sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --only)   ONLY="${2:-}"; shift 2 ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    -h|--help) usage 0 ;;
    -*) echo "unknown option: $1" >&2; usage 1 ;;
    *) SRC="$1"; shift ;;
  esac
done

# Resolve the folder: explicit path, a name under data/backups, or the newest.
if [ -z "$SRC" ]; then
  SRC="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r | head -1)"
  [ -n "$SRC" ] || { bad "no backups in ${BACKUP_ROOT#$ROOT/} — run 'lds backup' first"; exit 1; }
elif [ ! -d "$SRC" ] && [ -d "$BACKUP_ROOT/$SRC" ]; then
  SRC="$BACKUP_ROOT/$SRC"
fi
[ -d "$SRC" ] || { bad "not a folder: $SRC"; exit 1; }
[ -f "$SRC/manifest.tsv" ] || { bad "$SRC has no manifest.tsv — not an lds backup"; exit 1; }

MANIFEST="$SRC/manifest.tsv"
FAILED=0
running() { [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = "true" ]; }
wanted() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}
file_for() { # engine -> path (from manifest), empty when absent
  awk -F'\t' -v e="$1" '$1==e {print $2}' "$MANIFEST" | head -1
}

echo
info "Restore source: ${SRC#$ROOT/}"
printf '  %-14s %s\n' "ENGINE" "FILE"
awk -F'\t' '!/^#/ {printf "  %-14s %s\n", $1, $2}' "$MANIFEST"
echo
printf "${RED}This overwrites data in the running stack.${NC}\n"
if [ "$ASSUME_YES" != "1" ]; then
  printf 'Type "restore" to continue: '
  read -r answer
  [ "$answer" = "restore" ] || { echo "aborted"; exit 1; }
fi

# ---------------------------------------------------------------------------
restore_postgres() {
  local f="$SRC/$(file_for postgres)"
  [ -n "$(file_for postgres)" ] || { skip "postgres (not in this backup)"; return 0; }
  running lds-postgres || { bad "postgres: container not running (lds up postgres)"; FAILED=$((FAILED+1)); return 0; }
  info "postgres <- ${f#$SRC/}"
  gzip -dc "$f" | docker exec -i lds-postgres \
    psql -U "${POSTGRES_USER:-app}" -d postgres -v ON_ERROR_STOP=0 -q 2>&1 |
    grep -viE 'already exists|does not exist, skipping|^$' | sed 's/^/     /' | tail -20
  docker exec lds-postgres psql -U "${POSTGRES_USER:-app}" -d postgres -tAc \
    "SELECT count(*) FROM pg_database WHERE datname NOT IN ('template0','template1')" >/dev/null 2>&1
  ok "postgres"
}

restore_mysql() {
  local e=mysql
  [ -n "$(file_for $e)" ] || { skip "mysql (not in this backup)"; return 0; }
  running lds-mysql || { bad "mysql: container not running (lds up mysql)"; FAILED=$((FAILED+1)); return 0; }
  info "mysql <- $(file_for $e)"
  gzip -dc "$SRC/$(file_for $e)" |
    docker exec -i lds-mysql sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' 2>&1 |
    sed 's/^/     /' | tail -10
  ok "mysql"
}

restore_mariadb() {
  local e=mariadb
  [ -n "$(file_for $e)" ] || { skip "mariadb (not in this backup)"; return 0; }
  running lds-mariadb || { bad "mariadb: container not running (lds up mariadb)"; FAILED=$((FAILED+1)); return 0; }
  info "mariadb <- $(file_for $e)"
  gzip -dc "$SRC/$(file_for $e)" |
    docker exec -i lds-mariadb sh -c 'exec mysql -uroot -p"$MARIADB_ROOT_PASSWORD"' 2>&1 |
    sed 's/^/     /' | tail -10
  ok "mariadb"
}

restore_mongo() {
  local e=mongo
  [ -n "$(file_for $e)" ] || { skip "mongo (not in this backup)"; return 0; }
  running lds-mongo || { bad "mongo: container not running (lds up mongo)"; FAILED=$((FAILED+1)); return 0; }
  info "mongo <- $(file_for $e)"
  gzip -dc "$SRC/$(file_for $e)" | docker exec -i lds-mongo sh -c \
    'exec mongorestore --drop --archive --gzip --uri="mongodb://$MONGO_ROOT_USERNAME:$MONGO_ROOT_PASSWORD@localhost:27017/?authSource=admin"' \
    2>&1 | sed 's/^/     /' | tail -10
  ok "mongo"
}

restore_rdb() { # engine container
  local e="$1" c="$2" f
  f="$(file_for "$e")"
  [ -n "$f" ] || { skip "$e (not in this backup)"; return 0; }
  running "$c" || { skip "$e (container not running — start it and re-run to restore)"; return 0; }
  info "$e <- $f (stopping $c to swap dump.rdb)"
  docker stop "$c" >/dev/null 2>&1
  if docker cp "$SRC/$f" "$c:/data/dump.rdb" >/dev/null 2>&1; then
    docker start "$c" >/dev/null 2>&1
    ok "$e"
  else
    docker start "$c" >/dev/null 2>&1
    bad "$e"; FAILED=$((FAILED+1))
  fi
}

restore_mssql() {
  local sqlcmd=/opt/mssql-tools18/bin/sqlcmd
  local einst="$(awk -F'\t' '$1 ~ /^mssql\// {print $2}' "$MANIFEST")"
  [ -n "$einst" ] || { skip "mssql (not in this backup)"; return 0; }
  running lds-mssql || { bad "mssql: container not running (lds up mssql)"; FAILED=$((FAILED+1)); return 0; }
  local f db
  for f in $(awk -F'\t' '$1 ~ /^mssql\// {print $2}' "$MANIFEST"); do
    db="$(basename "$f" .bak)"
    info "mssql/$db <- $f"
    docker cp "$SRC/$f" "lds-mssql:/var/opt/mssql/backup/$db.bak" >/dev/null 2>&1
    docker exec lds-mssql sh -c "$sqlcmd -S localhost -U sa -P \"\$MSSQL_SA_PASSWORD\" -C \
      -Q \"RESTORE DATABASE [$db] FROM DISK='/var/opt/mssql/backup/$db.bak' WITH REPLACE\"" \
      >/dev/null 2>&1 && ok "mssql/$db" || { bad "mssql/$db"; FAILED=$((FAILED+1)); }
  done
}

restore_volumes() {
  local vols helper="${BACKUP_HELPER_IMAGE:-alpine:3.22}"
  vols=$(awk -F'\t' '$1 ~ /^volume\// {print $2}' "$MANIFEST")
  [ -n "$vols" ] || { skip "volumes (not in this backup)"; return 0; }
  local f name v
  for f in $vols; do
    name="$(basename "$f" .tgz)"; v="local-dev-stack_$name"
    info "volume/$name <- $f"
    docker volume create "$v" >/dev/null 2>&1
    docker run --rm --user 0:0 -v "$v:/data" -v "$SRC/volumes:/backup:ro" "$helper" \
      sh -c "rm -rf /data/* /data/..?* 2>/dev/null; tar -xzf /backup/$name.tgz -C /data" \
      >/dev/null 2>&1 && ok "volume/$name" || { bad "volume/$name"; FAILED=$((FAILED+1)); }
  done
}

# ---------------------------------------------------------------------------
wanted postgres && restore_postgres
wanted mysql    && restore_mysql
wanted mariadb  && restore_mariadb
wanted mongo    && restore_mongo
wanted redis    && restore_rdb redis lds-redis
wanted valkey   && restore_rdb valkey lds-valkey
wanted mssql    && restore_mssql
restore_volumes

echo
if [ "$FAILED" -gt 0 ]; then
  bad "$FAILED engine(s) failed — see above"
  exit 1
fi
ok "restore complete. Restart the affected services so they reconnect: lds restart <profile>"
