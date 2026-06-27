#!/usr/bin/env bash
# Initiate the single-node replica set (rs0) and ensure users exist. Handles
# both cases robustly:
#   - fresh DB (no users)     -> use the localhost exception to rs.initiate()
#                                and create the root + app users
#   - users already exist     -> authenticate and rs.initiate() that way
# Idempotent; auto-run by `lds up` for the mongo/all profile.
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
U="${MONGO_ROOT_USERNAME:-root}"
P="${MONGO_ROOT_PASSWORD:-root}"
AU="${MONGO_USER:-app}"
AP="${MONGO_PASSWORD:-app}"
DB="${MONGO_DATABASE:-app}"
C="lds-mongo"
RS="{_id:'rs0', members:[{_id:0, host:'mongo:27017'}]}"

noauth() { docker exec "$C" mongosh --quiet --eval "$1"; }
auth()   { docker exec "$C" mongosh --quiet -u "$U" -p "$P" --authenticationDatabase admin --eval "$1"; }

# Wait for mongod to accept connections (ping needs no auth).
for i in $(seq 1 30); do
  noauth 'db.adminCommand("ping").ok' >/dev/null 2>&1 && break
  [ "$i" = "30" ] && { echo "mongod not reachable in '$C' — is the mongo profile up?"; exit 1; }
  sleep 2
done

# Do valid root credentials already work? Use connectionStatus — it requires a
# valid login but (unlike listDatabases) works even before the RS has a primary.
if auth 'db.runCommand({connectionStatus:1}).authInfo.authenticatedUsers.length' 2>/dev/null | grep -q '^[1-9]'; then
  RUN=auth;   echo "Root user present — configuring replica set (authenticated)…"
else
  RUN=noauth; echo "Fresh DB — configuring replica set + users (localhost exception)…"
fi

# Initiate the replica set (idempotent: tolerate an already-initiated set).
$RUN "try { rs.initiate($RS) } catch (e) { if (!/already initialized/i.test(e.message)) throw e }"

# Wait until this node is PRIMARY (writable).
for i in $(seq 1 60); do
  $RUN 'db.hello().isWritablePrimary' 2>/dev/null | grep -q true && break
  [ "$i" = "60" ] && { echo "Replica set did not reach PRIMARY."; exit 1; }
  sleep 1
done

# On a fresh DB, create the root user now (still under the localhost exception).
if [ "$RUN" = "noauth" ]; then
  echo "Creating root user '$U'…"
  noauth "db.getSiblingDB('admin').createUser({user:'$U', pwd:'$P', roles:['root']})"
fi

# Ensure the app user exists (authenticated; idempotent).
echo "Ensuring app user '$AU' on '$DB'…"
auth "if (!db.getSiblingDB('$DB').getUser('$AU')) { db.getSiblingDB('$DB').createUser({user:'$AU', pwd:'$AP', roles:[{role:'readWrite', db:'$DB'}]}) }" >/dev/null 2>&1 || true

# Materialize the `app` database so it shows up by default (Mongo only lists a
# db once it has data; this creates an empty marker collection).
auth "try { db.getSiblingDB('$DB').createCollection('_init') } catch (e) {}" >/dev/null 2>&1 || true

echo "Mongo replica set ready (rs0)."
