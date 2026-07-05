#!/usr/bin/env bash
# One full LDS lifecycle from scratch:
#   init -> down -> rm -> build-bases (only if missing) -> up [profiles]
#   ./scripts/run/start.sh            # full reset, then up all
#   ./scripts/run/start.sh kafka php  # full reset, then up those profiles
# Teardown (down/rm) always covers everything; the profiles you pass go to `up`.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# --- step banners: show which phase of the lifecycle we're in --------------
TOTAL=5; N=0; STEP=""
banner() {
  N=$((N+1)); STEP="$1"
  printf '\n========================================================\n'
  printf   '  [%s/%s] %s\n' "$N" "$TOTAL" "$STEP"
  printf   '========================================================\n'
}
done_step() { printf -- '  ---- [%s/%s] %s: done ----\n' "$N" "$TOTAL" "$STEP"; }

banner "INIT — network + .env";              "$ROOT/scripts/run/init.sh"; done_step
banner "DOWN — stop/remove existing";        "$ROOT/scripts/run/down.sh"; done_step
banner "RM — force-remove containers";       "$ROOT/scripts/run/rm.sh";   done_step

# Build the lds/* bases ONLY if required core images are missing — distinct from
# the standalone `lds build-bases`, which always (re)builds them all.
banner "ENSURE BASE IMAGES — run build-bases only if lds/php or lds/nginx is missing"
[ -f .env ] && { set -a; . ./.env; set +a; }
need_bases=0
docker image inspect "lds/php:${PHP_VERSION:-8.4}" >/dev/null 2>&1 || need_bases=1
docker image inspect "lds/nginx:${NGINX_VERSION:-1.27}" >/dev/null 2>&1 || need_bases=1
if [ "$need_bases" -eq 1 ]; then
  echo "  required base image missing — handing off to build-bases…"
  "$ROOT/scripts/build/build-bases.sh"
else
  echo "  lds/php + lds/nginx already present — skipping (run 'lds build-bases' to force a rebuild)."
fi
done_step

banner "UP — ${*:-default toggles}";         "$ROOT/scripts/run/up.sh" "$@"; done_step

printf '\n========================================================\n'
printf   '  lds start: COMPLETE\n'
printf   '========================================================\n'
