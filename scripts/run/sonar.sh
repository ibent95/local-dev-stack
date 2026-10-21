#!/usr/bin/env bash
# Scan a project with SonarQube and push the report to the server.
#   lds tools sonar [path] [project-key]   scan a folder (default: current dir)
#   lds tools sonar token                  (re)create the cached scanner token
#   lds tools sonar reset                  restore the admin/admin login (recovery)
# The SERVER must be running: `lds up sonarqube` (UI at http://sonarqube.test /
# http://localhost:4544). The scanner is the pinned sonarsource/sonar-scanner-cli
# image (same tag as the sonar-scanner compose service), run against the server
# as http://sonarqube:9000 over the shared lds-network.
#
# Token handling: a scanner token is REQUIRED (unauthenticated analysis was
# removed in SonarQube 26.10). The wrapper resolves one in this order:
#   1. SONAR_TOKEN (env / .env)  — used only if THIS server accepts it
#   2. data/sonarqube/token      — the cached token, same check
#   3. bootstrap via the Web API — admin form login (SONAR_ADMIN_USER /
#      SONAR_ADMIN_PASSWORD, default admin/admin) + session cookie +
#      X-XSRF-TOKEN header, then user_tokens/generate (newer SonarQube removed
#      password basic auth; older servers fall back to it)
# Stale/foreign values (e.g. a global SONAR_TOKEN pointing at another server)
# are ignored with a warning. If the admin password was changed in the UI,
# either set SONAR_ADMIN_PASSWORD in .env (12+ chars incl. an uppercase
# letter), put a token from My Account -> Security into .env as
# SONAR_TOKEN=..., save it to data/sonarqube/token, or restore admin/admin
# with:  lds tools sonar reset.
#
# Other knobs (optional, in .env): SONAR_PROJECT_KEY (fixed key for every scan;
# a value inherited from the shell environment is IGNORED + flagged, since a
# stale copy would silently retarget every scan),
# SONAR_SOURCES (default "."), SONAR_EXCLUSIONS (comma glob list),
# SONAR_QUALITYGATE_WAIT=1 (block + fail until the quality gate decides).
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# A SONAR_PROJECT_KEY inherited from the shell environment would beat .env
# below (the loader only fills unset vars) - remember it for the warning, then
# drop it so only .env can supply the key. Long-lived terminals keep a stale
# copy for days and would otherwise silently retarget every scan.
ambient_key="${SONAR_PROJECT_KEY:-}"
unset SONAR_PROJECT_KEY

# Load .env so the SONAR_*/SONARQUBE_* vars are available (shell env still wins).
if [ -f "$ROOT/.env" ]; then
  while IFS='=' read -r k v; do
    k="${k%$'\r'}"
    case "$k" in ''|'#'*) continue ;; esac
    [ -z "${!k:-}" ] && export "$k=${v%$'\r'}"
  done < "$ROOT/.env"
fi

host="${SONARQUBE_HOST:-sonarqube.test}"
port="${SONARQUBE_HOST_PORT:-4544}"
base="http://127.0.0.1:${port}"
admin_user="${SONAR_ADMIN_USER:-admin}"
admin_pw="${SONAR_ADMIN_PASSWORD:-admin}"
token_name="${SONAR_TOKEN_NAME:-lds-scanner}"
token_file="$ROOT/data/sonarqube/token"
scanner_image="${SONAR_SCANNER_IMAGE:-sonarsource/sonar-scanner-cli}:${SONAR_SCANNER_VERSION:-12.2.0.4256_8.1.0}"
net="${NETWORK_NAME:-lds-network}"

# Wait for the server (up to ~2 min — first boot migrates the DB + starts ES).
wait_up() {
  local i status
  for i in $(seq 1 60); do
    status="$(curl -fsS --max-time 5 "$base/api/system/status" 2>/dev/null \
      | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([A-Z_]*\)".*/\1/p')" || true
    [ "$status" = "UP" ] && return 0
    sleep 2
  done
  return 1
}

# Is a token accepted by THIS server? Prints yes | no | unknown (unreachable).
validate_token() {
  local resp
  resp="$(curl -sS --max-time 8 -H "Authorization: Bearer $1" \
    "$base/api/authentication/validate" 2>/dev/null)" || { printf 'unknown'; return; }
  case "$resp" in
    *'"valid":true'*)  printf 'yes' ;;
    *'"valid":false'*) printf 'no' ;;
    *)                 printf 'unknown' ;;
  esac
}

# Create (or re-create) the scanner token via the Web API. Newer SonarQube
# versions removed password basic auth, so first try a form login (session
# cookie + X-XSRF-TOKEN header); fall back to basic for older servers. Always
# revokes a pre-existing token of the same name first. Reports the token on
# stdout; errors explain the manual fallback.
gen_token() {
  local jar hdr code xsrf resp tok auth=()
  jar="$(mktemp)"
  hdr="$(curl -sS -D - -o /dev/null -c "$jar" --max-time 15 -X POST \
    "$base/api/authentication/login" \
    --data-urlencode "login=${admin_user}" \
    --data-urlencode "password=${admin_pw}" 2>/dev/null)" || true
  code="$(printf '%s' "$hdr" | tr -d '\r' \
    | sed -n 's/^HTTP\/[0-9.]*[[:space:]]*\([0-9]\{3\}\).*/\1/p' | head -n1)"
  xsrf="$(printf '%s' "$hdr" | tr -d '\r' \
    | sed -n 's/^[Xx]-[Xx][Ss][Rr][Ff]-[Tt][Oo][Kk][Ee][Nn]:[[:space:]]*\(.*\)$/\1/p' | head -n1)"
  if [ "$code" = "200" ] && [ -n "$xsrf" ]; then
    auth=(-b "$jar" -H "X-XSRF-TOKEN: ${xsrf}")
  else
    auth=(-u "${admin_user}:${admin_pw}")   # legacy servers: password basic auth
  fi
  curl -sS "${auth[@]}" -X POST \
    "$base/api/user_tokens/revoke?name=${token_name}" >/dev/null 2>&1 || true
  resp="$(curl -sS "${auth[@]}" -X POST \
    "$base/api/user_tokens/generate?name=${token_name}" 2>/dev/null)" || resp=""
  rm -f "$jar"
  tok="$(printf '%s' "$resp" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  if [ -z "$tok" ]; then
    echo "error: could not create the scanner token (admin login failed or the name is taken)." >&2
    echo "       - check SONAR_ADMIN_USER/SONAR_ADMIN_PASSWORD in .env (custom passwords need 12+ chars incl. an uppercase letter)" >&2
    echo "       - or create a token in the UI (My Account -> Security) and either export" >&2
    echo "         SONAR_TOKEN=... or save it to data/sonarqube/token" >&2
    echo "       - if you are locked out, restore the default with:  lds tools sonar reset" >&2
    return 1
  fi
  mkdir -p "$(dirname "$token_file")"
  printf '%s' "$tok" > "$token_file"
  printf '%s' "$tok"
}

sub="${1:-}"

if [ "$sub" = "token" ]; then
  wait_up || { echo "SonarQube is not answering at $base — start it with:  lds up sonarqube"; exit 1; }
  echo "Re-creating scanner token '${token_name}' (cached in data/sonarqube/token)…"
  gen_token >/dev/null
  echo "Token stored in data/sonarqube/token."
  exit 0
fi

if [ "$sub" = "reset" ]; then
  # Documented recovery path (SonarQube docs, "Reinstating admin access"):
  # restore the PBKDF2 hash of the default 'admin' password. reset_password
  # stays false so the CLI bootstrap can log in without the UI's forced change.
  pg_db="${SONARQUBE_POSTGRES_DB:-lds_sonarqube}"
  pg_user="${SONARQUBE_POSTGRES_USER:-app}"
  echo "Restoring the SonarQube admin password to 'admin' (documented recovery query)…"
  docker exec lds-postgres psql -U "$pg_user" -d "$pg_db" -c \
    "update users set crypted_password='100000\$t2h8AtNs1AlCHuLobDjHQTn9XppwTIx88UjqUm4s8RsfTuXQHSd/fpFexAnewwPsO6jGFQUv/24DnO55hY6Xew==', salt='k9x9eN127/3e/hf38iNiKwVfaVk=', hash_method='PBKDF2', reset_password='false', user_local='true', active='true' where login='admin';" \
    || { echo "error: could not update the database — is the postgres container running?"; exit 1; }
  rm -f "$token_file"
  echo "Done. Admin login is 'admin' again and the cached scanner token was removed"
  echo "(the next scan recreates it)."
  if [ "${admin_pw}" != "admin" ]; then
    echo "note: .env sets SONAR_ADMIN_PASSWORD — run  lds up sonarqube  to apply it via the API."
  fi
  exit 0
fi

target="${1:-$PWD}"
target="$(cd "$target" 2>/dev/null && pwd)" || { echo "Target not found: ${1:-$PWD}"; echo "Pass a path to scan, e.g.  lds tools sonar ~/projects/php/svc-setting-lumen"; exit 1; }

key="${2:-${SONAR_PROJECT_KEY:-}}"
if [ -z "$key" ]; then
  key="$(basename "$target" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_.:-]/-/g; s/^[^a-z0-9]*//')"
  [ -n "$key" ] || key="lds-scan-$(date +%Y%m%d%H%M%S)"
fi
if [ -z "${2:-}" ] && [ -n "$ambient_key" ] && [ "$ambient_key" != "$key" ]; then
  echo "note: ignoring SONAR_PROJECT_KEY inherited from the shell environment ('$ambient_key')." >&2
  echo "      using '$key' as the project key (pass [project-key] or set SONAR_PROJECT_KEY in .env to pin it)." >&2
  echo "      old terminals keep a stale environment block — reopen them or reboot to clear it." >&2
fi

# Token resolution: a value the server actually accepts — SONAR_TOKEN (env /
# .env) > cached file > created via the API. Stale/foreign values (a global
# SONAR_TOKEN for another server, an old cached token) are ignored with a
# warning instead of failing the scan.
token=""
if [ -n "${SONAR_TOKEN:-}" ]; then
  case "$(validate_token "$SONAR_TOKEN")" in
    no) echo "warning: the SONAR_TOKEN in the environment is not accepted by this SonarQube server — ignoring it." >&2 ;;
    *)  token="$SONAR_TOKEN" ;;
  esac
fi
if [ -z "$token" ] && [ -f "$token_file" ]; then
  cached="$(cat "$token_file" 2>/dev/null || true)"
  if [ -n "$cached" ]; then
    case "$(validate_token "$cached")" in
      no) echo "warning: the cached token in data/sonarqube/token is stale — recreating it." >&2 ;;
      *)  token="$cached" ;;
    esac
  fi
fi
if [ -z "$token" ]; then
  wait_up || { echo "SonarQube is not answering at $base — start it with:  lds up sonarqube"; exit 1; }
  echo "No valid scanner token — creating '${token_name}' via the Web API (admin login)…"
  token="$(gen_token)" || exit 1
fi

# Docker Desktop on Windows wants a Windows path for -v; convert under git-bash.
src="$target"
if command -v cygpath >/dev/null 2>&1; then src="$(cygpath -w "$target")"; fi

# Optional scanner args. `sonar.sources`/`sonar.projectKey` are passed exactly
# once (the scanner rejects duplicated properties).
extra=()
[ -n "${SONAR_EXCLUSIONS:-}" ] && extra+=("-Dsonar.exclusions=${SONAR_EXCLUSIONS}")
case "${SONAR_QUALITYGATE_WAIT:-0}" in 1|true|TRUE|True|yes|on|y) extra+=("-Dsonar.qualitygate.wait=true") ;; esac

name="lds-sonar-scan-$(date +%Y%m%d%H%M%S)$(printf '%02d' $((RANDOM%100)))"
echo "Scanning $target with SonarQube (project key: $key) — container $name…"
set +e
docker run --rm --name "$name" --network "$net" \
  -e SONAR_HOST_URL=http://sonarqube:9000 \
  -e SONAR_TOKEN="$token" \
  -v "$src:/usr/src" -w /usr/src \
  "$scanner_image" \
  "-Dsonar.projectKey=$key" "-Dsonar.projectName=$key" "-Dsonar.sources=${SONAR_SOURCES:-.}" "${extra[@]}"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  echo "note: scanner exited with code $rc (3 = quality gate failed when SONAR_QUALITYGATE_WAIT=1)."
  echo "      the analysis may still be on the server — check the project URL below."
  exit "$rc"
fi

echo "Done. View the project at http://$host/dashboard?id=$key"
echo "(direct fallback: http://localhost:$port/dashboard?id=$key — run 'lds up sonarqube' if the server isn't up)."
