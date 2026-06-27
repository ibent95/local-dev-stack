#!/usr/bin/env bash
# Stop everything (all profiles).  Pass -v / --volumes to also delete data.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

extra=""
if [ "${1:-}" = "-v" ] || [ "${1:-}" = "--volumes" ]; then
  echo "Removing containers AND volumes (data will be lost)"
  extra="-v"
fi
docker compose --profile '*' down --remove-orphans $extra
