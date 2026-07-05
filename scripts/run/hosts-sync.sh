#!/usr/bin/env bash
# Fallback to the dns container: write each PHP project + stack web UI into
# /etc/hosts as <name>.test -> 127.0.0.1. Needs sudo. Only needed if you DON'T
# point your DNS at the dns container (which wildcard-resolves *.test for free).
# On Windows use hosts-sync.bat in an admin prompt instead.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
TLD=test
MARKER="# local-dev-stack"
HOSTS=/etc/hosts

# Load .env for PHP_PROJECTS_PATH + the web-UI hostnames (shell env wins).
if [ -f .env ]; then
  while IFS='=' read -r k v; do
    case "$k" in ''|'#'*) continue ;; esac
    [ -z "${!k:-}" ] && export "$k=$v"
  done < .env
fi
projdir="${PHP_PROJECTS_PATH:-./www}"

printf '\n========================================================\n'
printf   '  hosts-sync — writing *.test entries into %s\n' "$HOSTS"
printf   '========================================================\n'

tmp="$(mktemp)"
# Strip the previous managed block: every line we write carries $MARKER (the
# BEGIN/END banners and the per-category sub-headers too), so a single filter
# removes the whole grouped block and any legacy entries in one pass.
grep -v "$MARKER" "$HOSTS" > "$tmp" || true

count=0
bann()   { printf '%s   %s\n' "$1" "$MARKER" >> "$tmp"; }                 # managed comment -> file
group()  { bann "# --- $1 ---"; printf '\n  %s\n' "$1"; }                 # sub-header: file + console
add()    { printf '127.0.0.1\t%-24s%s\n' "$1" "$MARKER" >> "$tmp"; printf '    http://%-24s%s\n' "$1" "${2:-}"; count=$((count+1)); }

# Open the grouped block with a banner so it's visually distinct from any other
# entries already in the hosts file.
bann "# ===== local-dev-stack — managed by \`lds hosts-sync\` (do not edit below) ====="

# --- Projects: every folder under PHP_PROJECTS_PATH is served at <name>.test ---
group "Projects ($projdir)"
proj=0
for d in "$projdir"/*/; do
  [ -d "$d" ] || continue
  add "$(basename "$d").$TLD"; proj=$((proj+1))
done
if [ "$proj" -eq 0 ]; then bann "#   (no project folders yet)"; printf '    (none yet — drop a folder into %s)\n' "$projdir"; fi

# --- Tools & UIs: stack services routed by VIRTUAL_HOST (not www folders).
# Grouped to mirror the localhost control panel. Entries are harmless when the
# matching profile is off — the proxy just has nothing to route there yet. ---
group "Data tools"
add "${CACHE_ADMIN_HOST:-cache.test}"
add "${DB_ADMIN_HOST:-db.test}"

group "Security & auth"
add "${VAULTWARDEN_HOST:-vaultwarden.test}"

group "Database design"
add "${DRAWDB_HOST:-drawdb.test}" "(open via http://localhost:4423 — needs a secure context)"

group "Data warehouse & BI"
add "${SUPERSET_HOST:-superset.test}"
add "${HOP_HOST:-hop.test}"

group "Code quality"
add "${SEMGREP_HOST:-semgrep.test}"

group "Web analytics"
add "${ANALYTICS_HOST:-analytics.test}"

group "Project management"
add "${TASKS_HOST:-tasks.test}"

group "Documentation"
add "${WIKI_HOST:-wiki.test}"

group "Realtime & messaging"
add "${SOKETI_HOST:-ws.test}"
add "${CENTRIFUGO_HOST:-centrifugo.test}"
add "${MQTT_HOST:-mqtt.test}"

bann "# ===== end local-dev-stack ====="

sudo cp "$tmp" "$HOSTS"
rm -f "$tmp"
printf -- '\n  ---- hosts-sync: done (%s host(s) synced to %s) ----\n' "$count" "$HOSTS"
printf -- '  The control panel lives at http://localhost (no hosts entry needed).\n'
