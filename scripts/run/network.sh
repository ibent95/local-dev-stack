#!/usr/bin/env bash
# Manage the shared lds-network.  network.sh [status|create|rm|reset]
set -euo pipefail
NET="${NETWORK_NAME:-lds-network}"
action="${1:-status}"

exists()   { docker network inspect "$NET" >/dev/null 2>&1; }
attached() { docker network inspect "$NET" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null; }

do_create() {
  if exists; then echo "Network '$NET' already exists."
  else docker network create "$NET" >/dev/null && echo "Created network '$NET'."; fi
}

do_remove() {
  if ! exists; then echo "Network '$NET' does not exist."; return 0; fi
  local c; c="$(attached)"
  if [ -n "${c// /}" ]; then
    echo "Cannot remove '$NET' — containers still attached: $c"
    echo "Run './lds.sh down' (and stop any standalone projects) first."
    return 1
  fi
  docker network rm "$NET" >/dev/null && echo "Removed network '$NET'."
}

do_status() {
  if exists; then
    echo "Network '$NET': EXISTS"
    local c; c="$(attached)"
    [ -n "${c// /}" ] && echo "  attached: $c" || echo "  attached: (none)"
  else
    echo "Network '$NET': MISSING — run './lds.sh network create' (or './lds.sh init')."
  fi
}

case "$action" in
  status)    do_status ;;
  create)    do_create ;;
  rm|remove) do_remove ;;
  reset)     do_remove && do_create ;;
  *) echo "Usage: lds network [status|create|rm|reset]"; exit 1 ;;
esac
