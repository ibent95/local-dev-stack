#!/usr/bin/env bash
# Seed DBGate's connection list (in its data volume) so the stack databases are
# auto-listed on a FRESH setup — without using DBGate's CONNECTIONS env (which
# would lock the UI and disable "Add connection"). Idempotent: only seeds when
# the volume has no connections yet, so it never clobbers ones you added.
# Plaintext passwords are fine — DBGate treats non-`crypt:` values as plaintext
# and re-encrypts on first save. Passwords here are the .env DEFAULTS; if you
# changed DB creds, edit them in the UI afterwards (add/edit is enabled).
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Load .env for DBGATE_VERSION (used as the throwaway helper image — no new pull).
if [ -f .env ]; then
  while IFS='=' read -r k v; do
    case "$k" in ''|'#'*) continue ;; esac
    [ -z "${!k:-}" ] && export "$k=$v"
  done < .env
fi

VOL="local-dev-stack_dbgate-data"
SEED="configs/dbgate/connections.seed.jsonl"
[ -f "$SEED" ] || { echo "No DBGate seed file ($SEED) — skipping."; exit 0; }

# Create the volume with Compose's labels so `lds up` doesn't warn about an
# externally-created volume (we may create it here before Compose first runs).
docker volume inspect "$VOL" >/dev/null 2>&1 || docker volume create \
  --label com.docker.compose.project=local-dev-stack \
  --label com.docker.compose.volume=dbgate-data "$VOL" >/dev/null

docker run --rm -i -v "$VOL":/data "dbgate/dbgate:${DBGATE_VERSION:-7.2.0}" sh -c '
  if [ -s /data/connections.jsonl ]; then
    echo "DBGate already has connections — leaving them as-is."; exit 0
  fi
  cat > /data/connections.jsonl
  echo "Seeded DBGate with MySQL + Postgres + Mongo connections."
' < "$SEED"
