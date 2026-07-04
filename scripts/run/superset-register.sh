#!/usr/bin/env bash
# Register all Superset dashboard projects under SUPERSET_PROJECTS_PATH.
# Run by `lds up superset` (or manually). Idempotent: skips already-imported projects.
# Requires the superset container to be running.
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Load .env for SUPERSET_PROJECTS_PATH and SUPERSET_PROJECTS_CONTAINER_PATH.
if [ -f .env ]; then
  while IFS='=' read -r k v; do
    k="${k%$'\r'}"; v="${v%$'\r'}"   # strip \r from Windows line endings
    case "$k" in ''|'#'*) continue ;; esac
    [ -z "${!k:-}" ] && export "$k=$v"
  done < .env
fi

PROJ_DIR="${SUPERSET_PROJECTS_PATH:-./data/superset/projects}"
CTR_PROJ="${SUPERSET_PROJECTS_CONTAINER_PATH:-/app/superset_projects}"
CTR_NAME="lds-superset"
BIN="/app/.venv/bin"

# Ensure the host project directory exists.
mkdir -p "$PROJ_DIR"

# Check the superset container is running.
if ! docker inspect --format='{{.State.Running}}' "$CTR_NAME" 2>/dev/null | grep -q true; then
  echo "Superset container ($CTR_NAME) is not running — skipping project registration."
  exit 0
fi

# Get list of already-imported project folders by checking the marker file.
MARKER_DIR="$PROJ_DIR/.lds-imported"
mkdir -p "$MARKER_DIR"

count=0
for dir in "$PROJ_DIR"/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")

  # Skip hidden dirs (.lds-imported, etc.) and dirs with no YAML files.
  case "$name" in .*) continue ;; esac
  find "$dir" -maxdepth 2 -name '*.yaml' -o -name '*.yml' 2>/dev/null | head -1 | grep -q . || continue

  # Skip if already imported (marker file exists and is newer than the newest YAML).
  marker="$MARKER_DIR/$name.imported"
  if [ -f "$marker" ]; then
    newest_yaml=$(find "$dir" -name '*.yaml' -o -name '*.yml' 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
    if [ -n "$newest_yaml" ] && [ "$marker" -nt "$newest_yaml" ]; then
      continue
    fi
  fi

  # Import dashboards from this project folder into Superset.
  echo "Importing Superset project: $name"
  docker exec "$CTR_NAME" "$BIN/superset" import-dashboards \
    --path "$CTR_PROJ/$name" \
    --recursive \
    --overwrite 2>&1 || echo "  Warning: import returned non-zero for '$name' (may have no dashboards)."

  touch "$marker"
  count=$((count + 1))
done

if [ "$count" -gt 0 ]; then
  echo "Imported $count Superset project(s)."
else
  echo "All Superset projects already imported (or none found in $PROJ_DIR)."
fi
