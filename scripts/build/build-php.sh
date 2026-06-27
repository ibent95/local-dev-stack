#!/usr/bin/env bash
# Build (and optionally push) the custom PHP image.
#   ./scripts/build/build-php.sh            # build
#   ./scripts/build/build-php.sh --push     # build + push
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

docker compose --profile php build php

if [ "${1:-}" = "--push" ]; then
  img="$(docker compose --profile php config --images php)"
  echo "Pushing $img"
  docker push "$img"
fi
