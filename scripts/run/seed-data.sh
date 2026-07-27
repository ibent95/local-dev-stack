#!/usr/bin/env bash
# Seed sample Parquet/CSV/JSON data into data/duckdb/ and data/trino/.
# Idempotent — only generates files that don't exist yet; never overwrites
# user data. Uses the existing lds/python-dev base image (zero new pulls).
#
#   ./seed-data.sh          # seed if empty
#   ./seed-data.sh --force  # regenerate everything
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Load .env for PYTHON_VERSION (default 3.14)
PYTHON_VERSION="3.14"
if [ -f .env ]; then
  while IFS='=' read -r k v; do
    case "$k" in
      PYTHON_VERSION) PYTHON_VERSION="${v%$'\r'}" ;;
    esac
  done < .env
fi

IMAGE="lds/python-dev:${PYTHON_VERSION}"

FORCE=""
case "${1:-}" in
  --force|-f) FORCE="--force" ;;
esac

# Ensure target directories exist
mkdir -p data/duckdb data/trino

# Quick check: skip if not --force and files already exist
if [ -z "$FORCE" ]; then
  existing="$(find data/duckdb data/trino -maxdepth 1 \( -name '*.parquet' -o -name '*.csv' -o -name '*.jsonl' \) 2>/dev/null | head -5)"
  if [ -n "$existing" ]; then
    echo "Sample data already exists — skipping (use --force to regenerate)."
    exit 0
  fi
fi

# Build the base image if missing (idempotent — docker buildx bake skips if up-to-date)
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Building $IMAGE (first run)..."
  ( cd "$ROOT" && docker buildx bake -f docker-bake.hcl --load python-dev )
fi

echo "Seeding sample data into data/duckdb/ and data/trino/..."

docker run --rm \
  -v "$(pwd)/data:/data" \
  -v "$(pwd)/configs/seed-data/generate.py:/generate.py:ro" \
  "$IMAGE" sh -c "
    pip install -q pandas pyarrow 2>/dev/null
    python /generate.py ${FORCE}
  "

echo ""
echo "Sample data seeded. Files:"
find data/duckdb data/trino -maxdepth 1 -type f 2>/dev/null | sort | head -20
