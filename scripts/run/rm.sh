#!/usr/bin/env bash
# Force-remove containers for the given profiles (default: everything).
#   ./scripts/run/rm.sh              # all profiles
#   ./scripts/run/rm.sh kafka mysql  # only those profiles
# Uses `rm -fs`: -s stops running containers first, -f skips the confirm
# prompt (the compose equivalent of `docker rm -f`). Named data volumes are
# kept; pass -v yourself only if you also want anonymous volumes gone.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [ "$#" -eq 0 ]; then
  args=(--profile '*')
else
  args=(); for p in "$@"; do args+=(--profile "$p"); done
fi

echo "Force-removing containers for profiles: ${*:-all}"
docker compose "${args[@]}" rm -fs
