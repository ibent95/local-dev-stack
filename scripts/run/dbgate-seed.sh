#!/usr/bin/env bash
# Seed DBGate's connection list (in its bind-mounted data directory) so the
# stack databases are auto-listed on a FRESH setup — without using DBGate's
# CONNECTIONS env (which would lock the UI and disable "Add connection").
# Idempotent: only seeds when the directory has no connections yet, so it
# never clobbers ones you added. Plaintext passwords are fine — DBGate treats
# non-`crypt:` values as plaintext and re-encrypts on first save. Passwords
# here are the .env DEFAULTS; if you changed DB creds, edit them in the UI
# afterwards (add/edit is enabled).
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

DBDIR="data/dbgate"
SEED="configs/dbgate/connections.seed.jsonl"
[ -f "$SEED" ] || { echo "No DBGate seed file ($SEED) — skipping."; exit 0; }

# Ensure the bind-mount directory exists.
mkdir -p "$DBDIR"

# Idempotent: skip if connections already exist.
if [ -s "$DBDIR/connections.jsonl" ]; then
  echo "DBGate already has connections — leaving them as-is."; exit 0
fi

cp "$SEED" "$DBDIR/connections.jsonl"
echo "Seeded DBGate with MySQL + Postgres + Mongo connections."
