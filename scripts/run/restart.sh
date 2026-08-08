#!/usr/bin/env bash
# Restart profile-scoped services in-place.
#   lds restart                     # restart all services in this compose project
#   lds restart postgres valkey     # restart only services in those profiles
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

for a in "$@"; do
  if [ "$a" = "--rebuild" ]; then
    echo "restart does not build images. Use: lds up --rebuild <profiles...>"
    exit 1
  fi
done

if [ "$#" -eq 0 ]; then
  echo "Restarting all services..."
  docker compose --profile '*' restart
else
  profiles=("$@")
  profile_args=()
  for p in "${profiles[@]}"; do profile_args+=(--profile "$p"); done

  mapfile -t services < <(docker compose "${profile_args[@]}" config --services)
  if [ "${#services[@]}" -eq 0 ]; then
    echo "No services found for profiles: ${profiles[*]}"
    exit 1
  fi

  echo "Restarting profiles: ${profiles[*]}"
  echo "Matched services: ${services[*]}"
  docker compose restart "${services[@]}"
fi

docker compose --profile '*' ps
