#!/usr/bin/env bash
# Restart one or more profiles (down + rm + up with lifecycle).
# Delegates to `start.sh` which handles init → down → rm → build-bases → up.
#   lds restart                     # restart enabled toggles (from .env)
#   lds restart mysql redis         # restart specific profiles
#   lds restart --rebuild kafka     # restart with --build flag
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$ROOT/scripts/run/start.sh" "$@"
