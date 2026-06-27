#!/usr/bin/env bash
# Tail logs for a service (or all).  ./scripts/run/logs.sh kafka-broker
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
docker compose --profile '*' logs -f --tail=100 "$@"
