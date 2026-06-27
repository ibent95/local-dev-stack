#!/usr/bin/env bash
# Create the topics listed in KAFKA_TOPICS (replaces the old one-shot
# kafka-init service). Idempotent (--if-not-exists); safe to re-run any time.
#   KAFKA_TOPICS="name:partitions:replication,..."  (parts/repl default 1)
#   ./scripts/run/kafka-topics.sh
set -euo pipefail
# Git Bash on Windows rewrites Unix-looking args (e.g. the /opt/... path we pass
# to `docker exec`) into Windows paths. Disable that; harmless on Linux/macOS.
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Load .env so KAFKA_TOPICS (and friends) are available; shell env still wins.
if [ -f .env ]; then
  while IFS='=' read -r key val; do
    case "$key" in ''|'#'*) continue ;; esac
    [ -z "${!key:-}" ] && export "$key=$val"
  done < .env
fi

BROKER="lds-kafka-broker"
topics="${KAFKA_TOPICS:-}"
if [ -z "$topics" ]; then
  echo "KAFKA_TOPICS is empty — nothing to create."; exit 0
fi

# Wait until the broker answers (it's healthy after `up`, but be defensive).
for i in $(seq 1 20); do
  if docker exec "$BROKER" /opt/kafka/bin/kafka-topics.sh \
       --bootstrap-server localhost:9092 --list >/dev/null 2>&1; then
    break
  fi
  [ "$i" = "20" ] && { echo "Broker '$BROKER' not reachable — is the kafka profile up?"; exit 1; }
  sleep 2
done

IFS=',' read -ra specs <<< "$topics"
for spec in "${specs[@]}"; do
  name="${spec%%:*}"
  parts="$(echo "$spec" | cut -d: -f2)"; parts="${parts:-1}"
  repl="$(echo "$spec"  | cut -d: -f3)"; repl="${repl:-1}"
  echo "Creating topic '$name' (partitions=$parts, replication=$repl)"
  docker exec "$BROKER" /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 --create --if-not-exists \
    --topic "$name" --partitions "$parts" --replication-factor "$repl" >/dev/null \
    && echo "  ok" || echo "  (failed or already exists)"
done

echo "Topics now on the broker:"
docker exec "$BROKER" /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
