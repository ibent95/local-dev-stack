#!/usr/bin/env bash
# Install a Kafka Connect plugin into a worker's host-mounted plugin dir.
# Target which worker with an optional leading flag (default --generic):
#   --generic   -> configs/kafka/connect-generic/plugins  (vanilla worker, empty)
#   --debezium  -> configs/kafka/connect-debezium/plugins (alongside Debezium's CDC)
#
#   lds kafka connect-plugin [--generic|--debezium] jdbc        # known Apache-2.0 connector
#   lds kafka connect-plugin [--generic|--debezium] s3|http|opensearch
#   lds kafka connect-plugin [--generic|--debezium] <URL> [name]  # any connector .zip/.tar(.gz)
#
# Known shortcuts are Aiven's Apache-2.0 connectors (this stack is Confluent-free).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Target worker (optional leading flag; default generic).
target=generic
case "${1:-}" in
  --generic)  target=generic;  shift ;;
  --debezium) target=debezium; shift ;;
esac
if [ "$target" = debezium ]; then
  PLUGINS="$ROOT/configs/kafka/connect-debezium/plugins"; CTR="lds-kafka-connect-debezium"; PORT="${CONNECT_HOST_PORT:-4413}"
else
  PLUGINS="$ROOT/configs/kafka/connect-generic/plugins";  CTR="lds-kafka-connect-generic";  PORT="${CONNECT_GENERIC_HOST_PORT:-4412}"
fi

declare -A REPO=(
  [jdbc]="Aiven-Open/jdbc-connector-for-apache-kafka"
  [s3]="Aiven-Open/s3-connector-for-apache-kafka"
  [http]="Aiven-Open/http-connector-for-apache-kafka"
  [opensearch]="Aiven-Open/opensearch-connector-for-apache-kafka"
)

arg="${1:-}"; name="${2:-}"
if [ -z "$arg" ]; then
  echo "usage: lds connect-plugin <jdbc|s3|http|opensearch|URL> [name]"
  echo "known: ${!REPO[*]}"
  exit 1
fi

if [[ "$arg" == http*://* ]]; then
  url="$arg"
  name="${name:-$(basename "$url" | sed -E 's/\.(zip|tar\.gz|tgz|tar)$//')}"
else
  repo="${REPO[$arg]:-}"
  [ -z "$repo" ] && { echo "unknown connector '$arg' (known: ${!REPO[*]}) — or pass a release URL"; exit 1; }
  name="${name:-$arg}"
  echo "Resolving latest release asset of $repo…"
  # NOT /releases/latest: some releases ship no built artifact (only GitHub's
  # auto-generated source tarball), so scan recent releases (newest first) and
  # take the first real built asset (a browser_download_url archive).
  rel="$(curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=30")" \
    || { echo "GitHub API unreachable for $repo — pass a release URL directly:"; \
         echo "  lds kafka connect-plugin --generic <release-archive-URL> [name]"; exit 1; }
  url="$(printf '%s' "$rel" \
        | grep -oE '"browser_download_url": *"[^"]+"' \
        | sed -E 's/.*"(https[^"]+)".*/\1/' \
        | grep -iE '\.(tar\.gz|tgz|tar|zip)$' \
        | grep -viE '\.(asc|sha[0-9]*|md5|sig)$' \
        | head -1)"
  [ -z "$url" ] && { echo "no built release asset found for $repo — pass a release URL directly:"; \
        echo "  lds kafka connect-plugin --generic <release-archive-URL> [name]"; exit 1; }
fi

dest="$PLUGINS/$name"
tmp="$(mktemp -d)"; f="$tmp/pkg"
echo "Downloading $url"
curl -fSL "$url" -o "$f"
rm -rf "$dest"; mkdir -p "$dest"
case "$url" in
  *.zip)            unzip -oq "$f" -d "$dest" ;;
  *.tar.gz|*.tgz)   tar -xzf "$f" -C "$dest" ;;
  *.tar)            tar -xf  "$f" -C "$dest" ;;
  *) echo "unknown archive type for $url"; rm -rf "$tmp"; exit 1 ;;
esac
rm -rf "$tmp"

echo "Installed '$name' into $dest  (target: $target worker)"
echo "Load it into the worker:  docker restart $CTR"
echo "Then check:  curl -s localhost:$PORT/connector-plugins"
