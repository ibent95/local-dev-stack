#!/usr/bin/env bash
# Register Debezium connectors against Kafka Connect.
#   ./scripts/run/register-connectors.sh           # all *.json
#   ./scripts/run/register-connectors.sh mysql     # only matching
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# Debezium worker's REST endpoint (host 4413; generic worker is 4412).
CONNECT_URL="${CONNECT_URL:-http://localhost:4413}"
match="${1:-}"

shopt -s nullglob
files=("$ROOT"/configs/kafka/connect-debezium/*"$match"*connector.json)
if [ ${#files[@]} -eq 0 ]; then
  echo "No connector configs matched '$match'."; exit 0
fi

for f in "${files[@]}"; do
  echo "Registering $(basename "$f") -> $CONNECT_URL/connectors"
  if curl -sf -X POST -H "Content-Type: application/json" --data @"$f" \
       "$CONNECT_URL/connectors" >/dev/null; then
    echo "  OK"
  else
    echo "  (failed or already exists)"
  fi
done

echo "Active connectors:"
curl -s "$CONNECT_URL/connectors"; echo
