#!/usr/bin/env bash
# OpenVAS / Greenbone Community Edition companion — OUTSIDE the main stack
# (not a profile; managed by this command only).  (lds openvas <sub>)
#
#   lds openvas start|up [svc...]    start the stack (UI: http://127.0.0.1:9392,
#                                     TLS :8943, default login admin/admin)
#   lds openvas stop|down [svc...]   stop + remove containers (data kept in data/openvas/)
#   lds openvas restart [svc...]     restart services
#   lds openvas logs [svc...]        follow logs (first boot syncs feeds: 20-60+ min)
#   lds openvas ps [svc...]          status
#   lds openvas pull [svc...]        pre-pull the 18 images
#
# When the main stack's networks exist, an overlay (compose.lds.yml) is applied
# automatically: the web container joins lds-network (served at openvas.test via
# the LDS proxy) and the scanner joins lds-network + lds-dnsnet so *.test names
# resolve to the proxy from inside — you can scan http://myapp.test from the UI.
# Heavy: ~4+ GB RAM, multi-GB images, long first feed sync.
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

cmd="${1:-}"; [ $# -gt 0 ] && shift || true

files=(-f "$ROOT/configs/openvas/compose.yaml")
envf=()
[ -f "$ROOT/.env" ] && envf=(--env-file "$ROOT/.env")
if docker network inspect lds-network >/dev/null 2>&1 && docker network inspect lds-dnsnet >/dev/null 2>&1; then
  files+=(-f "$ROOT/configs/openvas/compose.lds.yml")
  echo "LDS overlay enabled (openvas.test via the proxy + *.test DNS for scans)."
else
  echo "note: lds-network/lds-dnsnet not found — starting without the LDS overlay."
  echo "      (start the main stack first, e.g. 'lds up proxy', then 'lds openvas restart')"
fi

case "$cmd" in
  start|up)
    docker compose "${files[@]}" "${envf[@]}" up -d "$@"
    echo
    echo "OpenVAS UI:  http://localhost:9392  (login admin/admin)"
    echo "             http://openvas.test    (via the LDS proxy, when the overlay is on)"
    echo "First boot syncs the vulnerability feeds — watch: lds openvas logs" ;;
  stop|down) docker compose "${files[@]}" "${envf[@]}" down "$@" ;;
  restart)   docker compose "${files[@]}" "${envf[@]}" restart "$@" ;;
  logs)      docker compose "${files[@]}" "${envf[@]}" logs "$@" ;;
  ps)        docker compose "${files[@]}" "${envf[@]}" ps "$@" ;;
  pull)      docker compose "${files[@]}" "${envf[@]}" pull "$@" ;;
  *) echo "usage: lds openvas <start|stop|restart|logs|ps|pull> [service...]"; exit 1 ;;
esac
