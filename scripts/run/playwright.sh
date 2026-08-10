#!/usr/bin/env bash
# Playwright End-To-End testing — scaffold projects, run tests, record tests.
#   lds playwright init <name> [url]      scaffold a test project
#   lds playwright run <name> [args…]     run its tests (extra args -> playwright CLI)
#   lds playwright codegen [url]          interactive test recorder (needs a TTY)
#   lds playwright shell                  open a shell in the runner container
#   lds playwright report                 print the HTML report viewer URL
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Load .env so the PLAYWRIGHT_* vars are available (shell env still wins).
if [ -f .env ]; then
  while IFS='=' read -r k v; do
    k="${k%$'\r'}"
    case "$k" in ''|'#'*) continue ;; esac
    [ -z "${!k:-}" ] && export "$k=${v%$'\r'}"
  done < .env
fi

CF=(-f docker-compose.yml)

usage() {
  cat <<'EOF'
usage: lds playwright <command> [args]

  init <name> [url]      scaffold a Playwright E2E project (data/playwright/projects/<name>)
  run <name> [args…]     run its tests inside the runner container (extra args -> playwright CLI)
  codegen [url]          open the interactive test recorder (needs a TTY)
  ui <name>              open Playwright UI Mode in your browser (localhost:4487)
  shell                  open a bash shell inside the runner container
  report                 show the HTML report viewer URL

Examples:
  lds playwright init myapp http://myapp.test
  lds playwright run myapp
  lds playwright run myapp -- --project=chromium
  lds playwright codegen http://myapp.test
EOF
}

# Make sure the playwright profile is up (pre-warms the runner + viewer).
ensure_up() {
  if [ -z "$(docker ps -q -f name=^/lds-playwright$)" ]; then
    echo "Starting playwright profile (first run pulls the image — be patient)…"
    docker compose "${CF[@]}" --profile playwright up -d playwright playwright-report
  fi
}

cmd="${1:-help}"
case "$cmd" in
  init)
    name="${2:-}"; url="${3:-}"
    if [ -z "$name" ]; then usage; exit 1; fi
    src="$ROOT/templates/e2e-template-playwright"
    [ -d "$src" ] || { echo "Missing template: $src"; exit 1; }
    base="${PLAYWRIGHT_PROJECTS_PATH:-./data/playwright/projects}"
    case "$base" in /*) dir="$base/$name" ;; *) dir="$ROOT/$base/$name" ;; esac
    [ -e "$dir" ] && { echo "Already exists: $dir"; exit 1; }
    mkdir -p "$(dirname "$dir")"
    cp -r "$src" "$dir"
    # Pin @playwright/test to the runner image's Playwright version.
    ver="${PLAYWRIGHT_VERSION:-v1.62.1-noble}"; ver="${ver#v}"; ver="${ver%%-*}"
    sed -i "s/\"@playwright\/test\": \"[^\"]*\"/\"@playwright\/test\": \"$ver\"/" "$dir/package.json"
    url="${url:-http://$name.test}"
    grep -rl -e '<NAME>' -e '<name>' -e '<URL>' "$dir" 2>/dev/null | while IFS= read -r f; do
      sed -i -e "s/<NAME>/$name/g" -e "s/<name>/$name/g" -e "s#<URL>#$url#g" "$f"
    done
    echo "Scaffolded Playwright E2E project -> $dir"
    echo "  target: $url"
    echo "  run:    lds playwright run $name"
    ;;
  run)
    name="${2:-}"; shift 2 2>/dev/null || shift 1
    if [ -z "$name" ]; then usage; exit 1; fi
    args=("$@")
    # Allow `lds playwright run <name> -- <playwright args>` (drop the --).
    [ "${args[0]:-}" = "--" ] && args=("${args[@]:1}")
    ensure_up
    docker compose "${CF[@]}" exec playwright bash -lc \
      "cd /e2e/projects/$name && { [ -d node_modules ] || npm install --no-audit --no-fund; } && npx playwright test \"\$@\"" _ "${args[@]}"
    ;;
  codegen)
    ensure_up
    docker compose "${CF[@]}" exec playwright npx playwright codegen "${2:-}"
    ;;
  ui)
    name="${2:-}"
    if [ -z "$name" ]; then usage; exit 1; fi
    ensure_up
    echo "Playwright UI Mode: open http://localhost:${PLAYWRIGHT_UI_HOST_PORT:-4487} in your browser"
    echo "  (UI server runs inside the container; Ctrl+C to stop)"
    docker compose "${CF[@]}" exec playwright bash -lc \
      "cd /e2e/projects/$name && { [ -d node_modules ] || npm install --no-audit --no-fund; } && npx playwright test --ui --ui-host=0.0.0.0 --ui-port=8787"
    ;;
  shell)
    ensure_up
    docker compose "${CF[@]}" exec playwright bash
    ;;
  report)
    ensure_up
    echo "Playwright report viewer: http://${PLAYWRIGHT_REPORT_HOST:-playwright.test}"
    echo "  (direct: http://localhost:${PLAYWRIGHT_REPORT_HOST_PORT:-4486})"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown playwright command: $cmd"; usage; exit 1
    ;;
esac
