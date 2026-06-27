#!/usr/bin/env bash
# Stop running containers WITHOUT removing them — keeps the containers (and all
# data) so `lds up` resumes them quickly. Contrast with:
#   down      removes the containers (data volumes kept)
#   down -v   removes containers AND wipes data volumes
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
echo "Stopping all running services (containers kept; 'lds up' resumes them)…"
docker compose --profile '*' stop
