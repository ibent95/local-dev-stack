#!/usr/bin/env bash
# Dump every RUNNING LDS database into one timestamped folder.
#   lds backup [--only mysql,postgres,...] [--out DIR] [--volumes] [--keep N] [--list]
#
# Why this exists: `lds down -v` is irreversible, and every profile keeps its
# state in a named volume or a bind mount. This takes a logical dump while the
# stack is UP, so a reset is recoverable — and each dump is plain SQL / an
# archive, so it can be inspected or loaded by hand as well.
#
# Layout (default root: data/backups, git-ignored):
#   data/backups/20261021-153000/
#     manifest.tsv          engine <tab> file <tab> sha256 <tab> bytes
#     postgres/postgres.sql.gz
#     mysql/mysql.sql.gz
#     mariadb/mariadb.sql.gz
#     mongo/mongo.archive.gz
#     redis/dump.rdb
#     valkey/valkey-data.tgz
#     mssql/<db>.bak
#     volumes/<volume>.tgz   (only with --volumes)
#
# Engines are dumped only when their container is RUNNING, so you can back up
# just the profiles you use. Oracle is not covered: Data Pump needs directory
# objects inside the database, so it is out of scope here (see docs).
#
# Restore with: lds restore <folder>   (default: the newest folder)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_ROOT="${BACKUP_DIR:-$ROOT/data/backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT=""
ONLY=""
VOLUMES=0
KEEP=""
LIST=0

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { printf "${BLUE}==>${NC} %s\n" "$*"; }
ok()    { printf "  ${GREEN}ok${NC}   %s\n" "$*"; }
skip()  { printf "  ${YELLOW}skip${NC} %s\n" "$*"; }
bad()   { printf "  ${RED}fail${NC} %s\n" "$*"; }

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --only)    ONLY="${2:-}"; shift 2 ;;
    --out)     OUT="${2:-}"; shift 2 ;;
    --volumes) VOLUMES=1; shift ;;
    --keep)    KEEP="${2:-}"; shift 2 ;;
    --list|-l) LIST=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown option: $1" >&2; usage 1 ;;
  esac
done

OUT="${OUT:-$BACKUP_ROOT/$STAMP}"
MANIFEST="$OUT/manifest.tsv"
FAILED=0

running() { [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = "true" ]; }

wanted() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

record() { # engine file
  local f="$2"
  [ -f "$f" ] || { FAILED=$((FAILED+1)); bad "$1 (no output)"; return 1; }
  local bytes sha
  bytes=$(wc -c <"$f" | tr -d ' ')
  sha=$(sha256sum "$f" | cut -d' ' -f1)
  printf '%s\t%s\t%s\t%s\n' "$1" "${f#$OUT/}" "$sha" "$bytes" >>"$MANIFEST"
  ok "$1 -> ${f#$OUT/} ($(numfmt --to=iec "$bytes" 2>/dev/null || echo "${bytes}B"))"
}

# ---------------------------------------------------------------------------
# Engines
# ---------------------------------------------------------------------------
dump_mysql() {
  running lds-mysql || { skip "mysql (not running)"; return 0; }
  mkdir -p "$OUT/mysql"
  # The password lives in the container's own env — never on the CLI.
  docker exec lds-mysql sh -c \
    'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --quick \
     --routines --triggers --events --hex-blob --databases app' 2>/dev/null |
    gzip -9 >"$OUT/mysql/mysql.sql.gz"
  record mysql "$OUT/mysql/mysql.sql.gz"
}

dump_mariadb() {
  running lds-mariadb || { skip "mariadb (not running)"; return 0; }
  mkdir -p "$OUT/mariadb"
  docker exec lds-mariadb sh -c \
    'exec mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --single-transaction --quick \
     --routines --triggers --events --hex-blob --databases app' 2>/dev/null |
    gzip -9 >"$OUT/mariadb/mariadb.sql.gz"
  record mariadb "$OUT/mariadb/mariadb.sql.gz"
}

dump_postgres() {
  running lds-postgres || { skip "postgres (not running)"; return 0; }
  mkdir -p "$OUT/postgres"
  # One file for ALL databases on the server (app + every lds_* tool DB).
  # --no-role-passwords keeps it readable without superuser access.
  docker exec lds-postgres pg_dumpall -U "${POSTGRES_USER:-app}" \
    --clean --if-exists --no-role-passwords 2>/dev/null |
    gzip -9 >"$OUT/postgres/postgres.sql.gz"
  record postgres "$OUT/postgres/postgres.sql.gz"
}

dump_mongo() {
  running lds-mongo || { skip "mongo (not running)"; return 0; }
  mkdir -p "$OUT/mongo"
  docker exec lds-mongo sh -c \
    'exec mongodump --uri="mongodb://$MONGO_ROOT_USERNAME:$MONGO_ROOT_PASSWORD@localhost:27017/?authSource=admin" \
     --archive --gzip' 2>/dev/null >"$OUT/mongo/mongo.archive.gz"
  record mongo "$OUT/mongo/mongo.archive.gz"
}

dump_redis() {
  running lds-redis || { skip "redis (not running)"; return 0; }
  mkdir -p "$OUT/redis"
  docker exec lds-redis redis-cli SAVE >/dev/null 2>&1
  docker cp lds-redis:/data/dump.rdb "$OUT/redis/dump.rdb" >/dev/null 2>&1
  record redis "$OUT/redis/dump.rdb"
}

dump_valkey() {
  running lds-valkey || { skip "valkey (not running)"; return 0; }
  mkdir -p "$OUT/valkey"
  docker exec lds-valkey valkey-cli SAVE >/dev/null 2>&1
  docker cp lds-valkey:/data/dump.rdb "$OUT/valkey/dump.rdb" >/dev/null 2>&1
  record valkey "$OUT/valkey/dump.rdb"
}

dump_mssql() {
  running lds-mssql || { skip "mssql (not running)"; return 0; }
  mkdir -p "$OUT/mssql"
  local sqlcmd=/opt/mssql-tools18/bin/sqlcmd
  docker exec lds-mssql sh -c "mkdir -p /var/opt/mssql/backup" >/dev/null 2>&1
  local dbs
  dbs=$(docker exec lds-mssql sh -c "$sqlcmd -S localhost -U sa -P \"\$MSSQL_SA_PASSWORD\" -C -h -1 -W \
        -Q \"SET NOCOUNT ON; SELECT name FROM sys.databases WHERE database_id > 4\"" 2>/dev/null |
        tr -d '\r' | sed '/^$/d')
  if [ -z "$dbs" ]; then bad "mssql (no user databases)"; FAILED=$((FAILED+1)); return 0; fi
  local d
  for d in $dbs; do
    docker exec lds-mssql sh -c "$sqlcmd -S localhost -U sa -P \"\$MSSQL_SA_PASSWORD\" -C \
      -Q \"BACKUP DATABASE [$d] TO DISK='/var/opt/mssql/backup/$d.bak' WITH INIT, COMPRESSION\"" \
      >/dev/null 2>&1 || bad "mssql: $d"
    docker cp "lds-mssql:/var/opt/mssql/backup/$d.bak" "$OUT/mssql/$d.bak" >/dev/null 2>&1
    record "mssql/$d" "$OUT/mssql/$d.bak"
  done
}

# Named volumes are the state that has no logical export (Grafana dashboards,
# Prometheus TSDB, Loki chunks, Penpot assets, RustFS objects, …). Tarballed
# read-only through a helper container — the service keeps running.
dump_volumes() {
  [ "$VOLUMES" = "1" ] || return 0
  [ -z "$ONLY" ] || { skip "volumes (--only given)"; return 0; }
  local helper="${BACKUP_HELPER_IMAGE:-alpine:3.22}"
  local vols
  vols=$(docker volume ls --format '{{.Name}}' | grep -E '^local-dev-stack_' || true)
  if [ -z "$vols" ]; then skip "volumes (none found)"; return 0; fi
  mkdir -p "$OUT/volumes"
  local v name
  for v in $vols; do
    name="${v#local-dev-stack_}"
    # Skip the databases: they already have logical dumps above.
    case "$name" in
      mysql-data|mariadb-data|mssql-data|oracle-data|postgres-data|mongo-data|mongo-config|redis-data|valkey-data)
        continue ;;
    esac
    docker run --rm --user 0:0 -v "$v:/data:ro" -v "$OUT/volumes:/backup" "$helper" \
      tar -czf "/backup/$name.tgz" -C /data . >/dev/null 2>&1 ||
      { bad "volume $name"; FAILED=$((FAILED+1)); continue; }
    record "volume/$name" "$OUT/volumes/$name.tgz"
  done
}

# ---------------------------------------------------------------------------
if [ "$LIST" = "1" ]; then
  [ -d "$BACKUP_ROOT" ] || { echo "no backups in $BACKUP_ROOT"; exit 0; }
  find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sort -r | while read -r d; do
    printf '%s  %s  %s\n' "$(basename "$d")" \
      "$(du -sh "$d" 2>/dev/null | cut -f1)" \
      "$(grep -c . "$d/manifest.tsv" 2>/dev/null || echo 0) item(s)"
  done
  exit 0
fi

mkdir -p "$OUT"
printf '# engine\tfile\tsha256\tbytes\n' >"$MANIFEST"
info "Backing up running LDS services to ${OUT#$ROOT/}"

wanted mysql     && dump_mysql
wanted mariadb   && dump_mariadb
wanted postgres  && dump_postgres
wanted mongo     && dump_mongo
wanted redis     && dump_redis
wanted valkey    && dump_valkey
wanted mssql     && dump_mssql
dump_volumes

# Nothing running at all is a failure, not a silent empty folder.
if [ "$(grep -vc '^#' "$MANIFEST")" = "0" ]; then
  rmdir "$OUT" 2>/dev/null
  bad "nothing to back up — is any data profile running? (lds ps)"
  exit 1
fi

# Retention: keep the N newest folders (--keep 5).
if [ -n "$KEEP" ] && [ "$KEEP" -gt 0 ] 2>/dev/null; then
  find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sort -r |
    tail -n +$((KEEP + 1)) | while read -r old; do
      info "pruning ${old#$ROOT/}"
      rm -rf "$old"
    done
fi

if [ "$FAILED" -gt 0 ]; then
  bad "$FAILED engine(s) failed — see above"
  exit 1
fi
ok "done — restore with: lds restore ${OUT#$ROOT/}"
