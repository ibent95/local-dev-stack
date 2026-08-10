#!/usr/bin/env bash
# Run a code-review-graph scan and export the interactive graph for the viewer.
#   lds tools crg <path> [<name>]   default path = current directory; name
#                                   defaults to the folder's basename (pass a
#                                   custom name to avoid collisions in the viewer).
#   lds tools crg clear             remove all reports.
# Results -> data/crg/reports/<name>/index.html, viewed at http://crg.test/<name>/
# The graph DB + .gitignore are written INSIDE the scanned repo (.code-review-graph/),
# so re-scanning the same repo is incremental. The graph is local-first — nothing
# leaves your machine. The AI/MCP integration is optional and runs on your host:
#   pip install code-review-graph && code-review-graph install
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# Load .env so the CRG_* vars are available (shell env still wins). Parse line-
# by-line (NOT `source`): .env holds unquoted multi-word values (e.g. PENPOT_FLAGS)
# that sourcing would try to execute as commands.
if [ -f "$ROOT/.env" ]; then
  while IFS='=' read -r k v; do
    k="${k%$'\r'}"
    case "$k" in ''|'#'*) continue ;; esac
    [ -z "${!k:-}" ] && export "$k=${v%$'\r'}"
  done < "$ROOT/.env"
fi

CRG_VERSION="${CRG_VERSION:-2.3.7}"
image="lds/crg:${CRG_VERSION}"
reports="$ROOT/data/crg/reports"

if [ "${1:-}" = "clear" ]; then
  rm -rf "$reports"
  echo "Cleared $reports"
  exit 0
fi

# Build the scanner image once (upstream ships no official image; the Dockerfile
# just pip-installs the pinned code-review-graph, so this is quick after the
# first python:3.12-slim pull). `lds up crg` pre-builds it too.
if ! docker image inspect "$image" >/dev/null 2>&1; then
  echo "Building $image (first use)…"
  docker build -q -t "$image" "$ROOT/configs/crg" >/dev/null
fi

target="${1:-$PWD}"
# Resolve to an absolute path against the CALLER's cwd (we don't cd to $ROOT
# first, so a relative path is taken relative to where you ran the command).
target="$(cd "$target" 2>/dev/null && pwd)" || { echo "Target not found: ${1:-$PWD}"; echo "Pass a path to scan, e.g.  lds tools crg ~/projects/php/svc-setting-lumen"; exit 1; }
name="${2:-$(basename "$target")}"
name="$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '_')"   # URL-path-safe

# Docker Desktop on Windows wants a Windows path for -v; convert under git-bash.
src="$target"
if command -v cygpath >/dev/null 2>&1; then src="$(cygpath -w "$target")"; fi

echo "Building the code graph for $target (container $image)…"
docker run --rm -v "$src:/src" -w /src "$image" build     || echo "  build reported an error — see output above"
docker run --rm -v "$src:/src" -w /src "$image" visualize || echo "  visualize reported an error — see output above"

outdir="$reports/$name"
mkdir -p "$outdir"
if [ -f "$target/.code-review-graph/graph.html" ]; then
  cp "$target/.code-review-graph/graph.html" "$outdir/index.html"
  echo "Wrote $outdir/index.html"
  echo "View at http://${CRG_HOST:-crg.test}/$name/  (run 'lds up crg' if the viewer isn't running)."
else
  echo "No graph.html produced — the scan did not complete. Re-run against a valid git repo."
  exit 1
fi
