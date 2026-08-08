#!/usr/bin/env bash
# Run a Trivy scan and write an HTML report for the viewer.  (lds tools trivy)
#   lds tools trivy [path]        fs scan — directory, repo, or dependency manifest
#   lds tools trivy image <name>  image scan (uses the local docker socket)
#   lds tools trivy clear         remove the current report + metadata
# Results -> data/trivy/reports/report.html, viewed at http://trivy.test
# (start the viewer: `lds up trivy`).
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
[ -f "$ROOT/.env" ] && { set -a; . "$ROOT/.env"; set +a; }

reports="$ROOT/data/trivy/reports"
cache="$ROOT/data/trivy/cache"
mkdir -p "$reports" "$cache"

if [ "${1:-}" = "clear" ]; then
  rm -f "$reports/report.html" "$reports/scan-meta.json"
  echo "Cleared $reports/report.html and scan metadata."
  exit 0
fi

mode=fs
if [ "${1:-}" = "image" ]; then
  mode=image
  shift
  [ $# -ge 1 ] || { echo "usage: lds tools trivy image <name>"; exit 1; }
fi
target="${1:-$PWD}"

# Docker Desktop on Windows wants a Windows path for -v; convert under git-bash.
out="$reports"; cdir="$cache"
if command -v cygpath >/dev/null 2>&1; then
  out="$(cygpath -w "$reports")"; cdir="$(cygpath -w "$cache")"
fi

# Run the SAME pinned image as the `trivy-scan` compose service (declared there
# + pre-pulled by `lds up trivy`). We use `docker run` rather than
# `docker compose run`: Compose's -v parser splits on ':' and chokes on a Windows
# drive-letter source (D:\…), leaving /src empty. The docker CLI handles D:\…
# correctly. The vulnerability DB is cached in data/trivy/cache (shared with the
# compose service), so it downloads once, not per scan.
# Static, unique container name (timestamp + 2 random digits) instead of Docker's
# random name — recognizable in `docker ps` and unique across concurrent runs.
name="lds-trivy-scan-$(date +%Y%m%d%H%M%S)$(printf '%02d' $((RANDOM%100)))"
image_tag="${TRIVY_IMAGE:-aquasec/trivy}:${TRIVY_VERSION:-0.58.1}"
trivy_timeout="${TRIVY_TIMEOUT:-30m}"
trivy_scanners="${TRIVY_SCANNERS:-vuln}"

if [ "$mode" = "image" ]; then
  echo "Scanning image '$target' with Trivy (CVE DB cached in data/trivy/cache) — container $name…"
  docker run --rm --name "$name" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$out:/out" -v "$cdir:/root/.cache/trivy" \
    "$image_tag" image --scanners "$trivy_scanners" --timeout "$trivy_timeout" --format template --template "@/contrib/html.tpl" --output /out/report.html "$target"
  target_meta="$target"
else
  # Resolve to an absolute path against the CALLER's cwd (we don't cd to $ROOT
  # first, so a relative path is taken relative to where you ran the command).
  target="$(cd "$target" 2>/dev/null && pwd)" || { echo "Target not found: ${1:-$PWD}"; echo "Pass a path to scan, e.g.  lds tools trivy ~/projects/php/svc-setting-lumen"; exit 1; }
  src="$target"
  if command -v cygpath >/dev/null 2>&1; then src="$(cygpath -w "$target")"; fi
  echo "Scanning $target with Trivy (fs) — container $name…"
  docker run --rm --name "$name" \
    -v "$src:/src" -v "$out:/out" -v "$cdir:/root/.cache/trivy" -w /src \
    "$image_tag" fs --scanners "$trivy_scanners" --timeout "$trivy_timeout" --format template --template "@/contrib/html.tpl" --output /out/report.html /src
  target_meta="$target"
fi

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
target_json="$(printf '%s' "$target_meta" | sed 's/\\/\\\\/g; s/"/\\"/g')"
scanners_json="$(printf '%s' "$trivy_scanners" | sed 's/\\/\\\\/g; s/"/\\"/g')"
timeout_json="$(printf '%s' "$trivy_timeout" | sed 's/\\/\\\\/g; s/"/\\"/g')"
cat > "$reports/scan-meta.json" <<EOF
{"tool":"trivy","mode":"$mode","target":"$target_json","scanners":"$scanners_json","timeout":"$timeout_json","scanned_at":"$now"}
EOF

echo "Wrote $reports/report.html"
echo "View at http://${TRIVY_HOST:-trivy.test}  (run 'lds up trivy' if the viewer isn't running)."
