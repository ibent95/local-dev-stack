#!/usr/bin/env bash
# Register all Hop projects under HOP_PROJECTS_PATH into hop-config.json.
# Run by `lds up hop` (or manually). Idempotent: skips already-registered projects.
# Requires the hop container to be running.
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Load .env for HOP_PROJECTS_PATH and HOP_PROJECTS_CONTAINER_PATH.
if [ -f .env ]; then
  while IFS='=' read -r k v; do
    case "$k" in ''|'#'*) continue ;; esac
    [ -z "${!k:-}" ] && export "$k=$v"
  done < .env
fi

PROJ_DIR="${HOP_PROJECTS_PATH:-./data/hop/projects}"
CTR_PROJ="${HOP_PROJECTS_CONTAINER_PATH:-/usr/local/tomcat/projects}"
CTR_NAME="lds-hop"

# Ensure the host project directory exists.
mkdir -p "$PROJ_DIR"

# Check the hop container is running.
if ! docker inspect --format='{{.State.Running}}' "$CTR_NAME" 2>/dev/null | grep -q true; then
  echo "Hop container ($CTR_NAME) is not running — skipping project registration."
  exit 0
fi

# Get list of already-registered projects from hop-config.json inside the container.
registered=$(docker exec "$CTR_NAME" sh -c '
  cfg=/usr/local/tomcat/webapps/ROOT/config/hop-config.json
  if [ -f "$cfg" ]; then
    cat "$cfg" | tr "," "\n" | grep "\"projectName\"" | sed "s/.*\"projectName\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/"
  fi
' 2>/dev/null || true)

count=0
for dir in "$PROJ_DIR"/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  [ -f "$dir/project-config.json" ] || continue

  # Skip if already registered.
  if echo "$registered" | grep -qxF "$name"; then
    continue
  fi

  # Register via hop-conf inside the container.
  echo "Registering Hop project: $name"
  docker exec "$CTR_NAME" sh -c "
    cd /usr/local/tomcat/webapps/ROOT
    ./hop-conf.sh --project-create --project '$name' --project-home '$CTR_PROJ/$name' 2>&1
  " || echo "  Warning: hop-conf returned non-zero for '$name' (may already exist)."
  count=$((count + 1))
done

if [ "$count" -gt 0 ]; then
  echo "Registered $count new Hop project(s)."
else
  echo "All Hop projects already registered (or none found in $PROJ_DIR)."
fi
