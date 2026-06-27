#!/usr/bin/env bash
# Run a Semgrep scan and write SARIF for the viewer.  (lds tools semgrep [path])
#   default path = current directory. Results -> configs/semgrep/reports/report.sarif,
#   viewed at http://semgrep.test (start the viewer: `lds up semgrep`).
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
[ -f "$ROOT/.env" ] && { set -a; . "$ROOT/.env"; set +a; }

target="${1:-$PWD}"
# Resolve to an absolute path against the CALLER's cwd (we don't cd to $ROOT
# first, so a relative path is taken relative to where you ran the command).
target="$(cd "$target" 2>/dev/null && pwd)" || { echo "Target not found: ${1:-$PWD}"; echo "Pass a path to scan, e.g.  lds tools semgrep ~/projects/php/svc-setting-lumen"; exit 1; }
reports="$ROOT/configs/semgrep/reports"
mkdir -p "$reports"

# Docker Desktop on Windows wants a Windows path for -v; convert under git-bash.
src="$target"; out="$reports"
if command -v cygpath >/dev/null 2>&1; then src="$(cygpath -w "$target")"; out="$(cygpath -w "$reports")"; fi

# Run the SAME pinned image as the `semgrep-scan` compose service (declared there
# + pre-pulled by `lds up semgrep`). We use `docker run` rather than
# `docker compose run`: Compose's -v parser splits on ':' and chokes on a Windows
# drive-letter source (D:\…), leaving /src empty ("Detected Docker environment
# without a code volume"). The docker CLI handles D:\… correctly.
rules="${SEMGREP_RULES:-p/default}"
# `auto` REQUIRES telemetry (it uploads project metadata to semgrep.dev to pick
# rules), so it can't run with metrics off. Every other config (p/…, a URL, or a
# local YAML) works with metrics OFF — which we prefer, because metrics-on's
# end-of-run upload hangs on slow/offline links (looks like the CLI never exits).
# So: metrics off by default; flip on ONLY for auto.
metrics=off; [ "$rules" = "auto" ] && metrics=on
# Static, unique container name (timestamp + 2 random digits) instead of Docker's
# random name — recognizable in `docker ps` and unique across concurrent runs.
name="lds-semgrep-scan-$(date +%Y%m%d%H%M%S)$(printf '%02d' $((RANDOM%100)))"
echo "Scanning $target with Semgrep (rules: $rules, metrics: $metrics) — container $name…"
docker run --rm --name "$name" -v "$src:/src" -v "$out:/out" -w /src \
  "${SEMGREP_IMAGE:-semgrep/semgrep}:${SEMGREP_VERSION:-1.167.0}" \
  semgrep scan --metrics "$metrics" --config "$rules" --sarif --output /out/report.sarif || true

echo "Wrote $reports/report.sarif"
echo "View at http://${SEMGREP_HOST:-semgrep.test}  (run 'lds up semgrep' if the viewer isn't running)."
