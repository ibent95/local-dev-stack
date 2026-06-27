#!/bin/sh
# Your scheduled task. Output goes to stdout (lds app logs). Keep it idempotent.
set -eu
echo "[$(date -Iseconds)] cron-template-shell: ran on $(hostname)"

# Backing services are reachable by name on lds-network, e.g.:
#   curl -fsS http://my-svc:8080/health
#   apk add --no-cache redis && redis-cli -h redis ping
