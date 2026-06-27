#!/usr/bin/env bash
# Manage an app project (a svc-/web- template) — its own docker compose, in its
# own folder. Subcommands:
#   lds app start   [dir]        ensure proxy/dns/network, then build & start
#   lds app stop    [dir] [-v]   stop the project (docker compose down)
#   lds app restart [dir]        rebuild & recreate
#   lds app logs    [dir] [svc]  tail the project's logs
#   lds app ps      [dir]        status of the project's containers
# dir defaults to the current directory; extra args pass through to compose.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

usage() {
  cat <<'EOF'
Usage: lds app <command> [dir] [args]
  start   [dir]        ensure proxy + build & start (docker compose up --build -d)
  stop    [dir] [-v]   stop the project (docker compose down)
  restart [dir]        rebuild & recreate (up --build -d --force-recreate)
  logs    [dir] [svc]  tail the project's logs
  ps      [dir]        status of the project's containers
dir defaults to the current directory.
EOF
}

sub="${1:-}"
case "$sub" in
  start|stop|restart|logs|ps) shift ;;
  ''|-h|--help|help) usage; exit 0 ;;
  *) echo "Unknown app command: '$sub'"; echo; usage; exit 1 ;;
esac

# First remaining arg is the project dir unless it looks like a flag.
dir="."
if [ "$#" -gt 0 ] && [ "${1#-}" = "$1" ]; then dir="$1"; shift; fi

if [ ! -f "$dir/docker-compose.yml" ] && [ ! -f "$dir/compose.yml" ] && [ ! -f "$dir/compose.yaml" ]; then
  echo "No compose file in '$dir' — run this from the project folder, or pass its path."
  echo "  e.g. lds app $sub ../../Go/orders"
  exit 1
fi

case "$sub" in
  start)
    echo "==> ensuring LDS proxy + dns + network are up"
    "$ROOT/scripts/run/up.sh" proxy
    echo "==> building + starting project in: $dir"
    ( cd "$dir" && docker compose up --build -d "$@" && docker compose ps )
    host="$(cd "$dir" && docker compose config 2>/dev/null | grep -oE 'VIRTUAL_HOST:[^,]*' | head -1 | awk '{print $2}')"
    [ -n "$host" ] && echo "==> open: http://$host"
    ;;
  stop)
    echo "==> stopping project in: $dir"
    ( cd "$dir" && docker compose down "$@" )
    ;;
  restart)
    echo "==> rebuilding + recreating project in: $dir"
    ( cd "$dir" && docker compose up --build -d --force-recreate "$@" && docker compose ps )
    ;;
  logs)
    ( cd "$dir" && docker compose logs -f "$@" )
    ;;
  ps)
    ( cd "$dir" && docker compose ps "$@" )
    ;;
esac
