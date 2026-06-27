#!/usr/bin/env bash
# One-time: create the shared `lds-network` network (idempotent).
set -euo pipefail
NET="${NETWORK_NAME:-lds-network}"
if docker network inspect "$NET" >/dev/null 2>&1; then
  echo "Network '$NET' already exists."
else
  docker network create "$NET" >/dev/null
  echo "Created shared network '$NET'."
fi
