#!/usr/bin/env bash
# Stop containers for the given profiles (default: everything).
#   ./scripts/run/down.sh                # all profiles
#   ./scripts/run/down.sh kafka mysql    # only those profiles
#   ./scripts/run/down.sh -v             # + wipe volumes (all profiles)
#   ./scripts/run/down.sh kafka -v       # + wipe volumes (specific profiles)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Extract -v / --volumes from the argument list
extra=""; args=()
for a in "$@"; do
  case "$a" in
    -v|--volumes) extra="-v" ;;
    *) args+=("$a") ;;
  esac
done

if [ "${#args[@]}" -eq 0 ]; then
  # No profile args → stop everything
  [ -n "$extra" ] && echo "Removing containers AND volumes (data will be lost)"
  docker compose --profile '*' down --remove-orphans $extra
else
  compose_args=(); for p in "${args[@]}"; do compose_args+=(--profile "$p"); done
  echo "Stopping containers for profiles: ${args[*]}"
  [ -n "$extra" ] && echo "Removing volumes (data will be lost)"
  docker compose "${compose_args[@]}" down --remove-orphans $extra
fi
