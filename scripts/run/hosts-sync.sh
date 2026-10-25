#!/usr/bin/env bash
# Fallback to the dns container: write each PHP project + stack web UI into the
# OS hosts file as <name>.test -> 127.0.0.1.
#
#   Linux / WSL   /etc/hosts                          (root or sudo)
#   Git Bash      %WINDIR%\System32\drivers\etc\hosts (the file Windows DNS and
#                 browsers read - NOT Git's own /etc/hosts, which nothing else
#                 on Windows consults). Writing it needs elevation; when the
#                 shell is not elevated run hosts-sync.bat from an Administrator
#                 prompt instead.
#
# Only needed if you DON'T point your DNS at the dns container (it wildcard-
# resolves *.test for free).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
TLD=test
MARKER="# local-dev-stack"

# --- Pick the hosts file DNS clients actually read -------------------------
WINDOWS=0
OS="$(uname -s 2>/dev/null || echo unknown)"
case "$OS" in
  MINGW*|MSYS*|CYGWIN*)
    WINDOWS=1
    win_hosts="${WINDIR:-C:\\Windows}/System32/drivers/etc/hosts"
    if command -v cygpath >/dev/null 2>&1; then
      HOSTS="$(cygpath -u "$win_hosts")"
    else
      HOSTS="$win_hosts"
    fi
    ;;
  *) HOSTS=/etc/hosts ;;
esac
# Custom target (containers, unusual prefixes, tests).
HOSTS="${LDS_HOSTS_FILE:-$HOSTS}"

# Load .env for PHP_PROJECTS_PATH + the web-UI hostnames (shell env wins).
# A trailing CR is stripped from both fields: on a CRLF checkout `.env` would
# otherwise leak "value\r" into the environment (and a blank CRLF line would
# even produce the invalid variable name "\r").
if [ -f .env ]; then
  while IFS='=' read -r k v || [ -n "$k" ]; do
    k="${k%$'\r'}"
    v="${v%$'\r'}"
    case "$k" in ''|'#'*|[[:space:]]*) continue ;; esac
    [ -z "${!k:-}" ] && export "$k=$v"
  done < .env
fi
projdir="${PHP_PROJECTS_PATH:-./www}"

if [ ! -e "$HOSTS" ]; then
  printf 'hosts-sync: hosts file not found: %s\n' "$HOSTS" >&2
  exit 1
fi

printf '\n========================================================\n'
printf   '  hosts-sync — writing *.test entries into %s\n' "$HOSTS"
printf   '  platform: %s%s\n' "$OS" "$( [ "$WINDOWS" = 1 ] && printf ' (Windows hosts file)' || true )"
printf   '========================================================\n'

tmp="$(mktemp)"
trap 'rm -f "$tmp" "$tmp.crlf"' EXIT

# Strip the previous managed block: every line we write carries $MARKER (the
# BEGIN/END banners and the per-category sub-headers too), so a single filter
# removes the whole grouped block and any legacy entries in a single pass.
# Normalise CRLF first so the rewritten file has exactly one kind of line ending.
if [ -r "$HOSTS" ]; then
  sed 's/\r$//' "$HOSTS" | grep -v -- "$MARKER" > "$tmp" || true
else
  : > "$tmp"
fi

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
group "Admin tools"
add "${CACHE_ADMIN_HOST:-cache.test}"
add "${DB_ADMIN_HOST:-db.test}"

group "Auth"
add "${VAULTWARDEN_HOST:-vaultwarden.test}"
add "${KEYCLOAK_HOST:-auth.test}" "(OIDC/OAuth2 · issuer /realms/lds · admin/admin)"

group "Communication tools"
add "${MAIL_HOST:-mail.test}"
add "${OPENWA_HOST:-openwa.test}"

group "Browser automation"
add "${HEADLESSX_HOST:-headlessx.test}"
add "${HEADLESSX_API_HOST:-headlessx-api.test}" "(MCP + API — headlessx-api.test)"

group "Designers"
add "${PENPOT_HOST:-penpot.test}"
add "${DRAWDB_HOST:-drawdb.test}" "(open via http://localhost:4502 — needs a secure context)"
add "${DRAWIO_HOST:-drawio.test}" "(self-hosted diagrams — use ?offline=1&https=0)"

group "File conversion"
add "${SNAPOTTER_HOST:-snapotter.test}" "(file platform - convert · OCR · AI)"
add "${IMGCOMPRESS_HOST:-imgcompress.test}" "(image toolbox - 70+ formats)"

group "Data tools"
add "${SUPERSET_HOST:-superset.test}"
add "${METABASE_HOST:-metabase.test}"
add "${HOP_HOST:-hop.test}"

group "API & project management"
add "${HOPPSCOTCH_HOST:-hoppscotch.test}" "(API client - Postman alternative)"
add "${PLANE_HOST:-plane.test}" "(project management - Jira/Linear alternative)"

group "Code quality"
add "${SEMGREP_HOST:-semgrep.test}"
add "${SONARQUBE_HOST:-sonarqube.test}" "(code quality — bugs · coverage · quality gates)"
add "${CRG_HOST:-crg.test}" "(code-review-graph — AI code graph · blast-radius)"

group "Testing tools"
add "${PLAYWRIGHT_REPORT_HOST:-playwright.test}" "(Playwright E2E report viewer)"

group "Security tools"
add "${TRIVY_HOST:-trivy.test}"
add "${ZAP_HOST:-zap.test}"
add "${OPENVAS_HOST:-openvas.test}" "(OpenVAS/Greenbone companion — start with 'lds openvas start')"

group "LDS apps"
add "${ANALYTICS_HOST:-lds-analytics.test}"
add "${TASKS_HOST:-lds-tasks.test}"
add "${WIKI_HOST:-lds-wiki.test}"

group "Analytical query engines"
add "${DUCKDB_HOST:-duckdb.test}"

group "Search"
add "${MEILISEARCH_HOST:-meili.test}" "(API-only, no web UI, development mode)"

group "Monitoring"
add "${PROMETHEUS_HOST:-prometheus.test}" "(metrics TSDB)"
add "${GRAFANA_HOST:-grafana.test}" "(dashboards - admin/admin)"
add "${LOKI_HOST:-loki.test}" "(log store - API only; root opens Grafana Explore)"
add "${TEMPO_HOST:-tempo.test}" "(trace store - OTLP in; root opens Grafana Explore)"

group "Realtime dashboards"
add "${SOKETI_HOST:-ws.test}"
add "${CENTRIFUGO_HOST:-centrifugo.test}"
add "${MQTT_HOST:-mqtt.test}"

group "Storage tools"
add "${RUSTFS_HOST:-rustfs.test}"

group "Websites & CMS"
add "${INSTATIC_HOST:-instatic.test}" "(visual CMS — admin at /admin)"

group "ERP & business"
add "${ERPNEXT_HOST:-erpnext.test}" "(accounting · CRM · HR — admin/admin)"

bann "# ===== end local-dev-stack ====="

# Windows' hosts file is CRLF; rewrite the whole buffer so mixed endings never
# sneak in (a stray \r inside an entry is a classic silent DNS failure).
if [ "$WINDOWS" = 1 ]; then
  sed 's/$/\r/' "$tmp" > "$tmp.crlf"
  mv -f "$tmp.crlf" "$tmp"
fi

# --- Install the generated file -------------------------------------------
# `[ -w ]` is unreliable under MSYS (Windows ACLs are not mapped onto the git
# mode bits), so attempt the copy and fall through with an actionable message
# instead of letting a raw `cp: Permission denied` abort the script.
wrote=0
if cp "$tmp" "$HOSTS" 2>/dev/null; then
  wrote=1
elif [ "$(id -u 2>/dev/null || echo 1)" -eq 0 ] && cp "$tmp" "$HOSTS" 2>/dev/null; then
  wrote=1
elif [ "$WINDOWS" = 0 ] && command -v sudo >/dev/null 2>&1 && sudo cp "$tmp" "$HOSTS"; then
  wrote=1
fi

if [ "$wrote" -eq 0 ]; then
  printf '\n  ERROR: cannot write %s\n' "$HOSTS" >&2
  if [ "$WINDOWS" = 1 ]; then
    printf '  It needs Administrator rights. Re-run from an elevated prompt:\n' >&2
    printf '    Command Prompt (Run as administrator): scripts\\run\\hosts-sync.bat\n' >&2
    printf '    or start Git Bash as Administrator and re-run this command.\n' >&2
  else
    printf '  Re-run as root, or install sudo.\n' >&2
  fi
  printf '  The generated block was kept at: %s\n' "$tmp" >&2
  trap - EXIT
  exit 1
fi

# Windows caches failed lookups; flush so the new *.test names resolve now.
if [ "$WINDOWS" = 1 ]; then
  # </dev/null matters: cmd inherits the shell's stdin and can block forever on
  # a pipe (e.g. when the script itself runs from CI/agent tooling).
  MSYS2_ARG_CONV_EXCL='*' cmd //c ipconfig /flushdns </dev/null >/dev/null 2>&1 || true
fi

printf -- '\n  ---- hosts-sync: done (%s host(s) synced to %s) ----\n' "$count" "$HOSTS"
printf -- '  The control panel lives at http://localhost (no hosts entry needed).\n'
