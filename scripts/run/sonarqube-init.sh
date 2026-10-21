#!/usr/bin/env bash
# Ensure Postgres has the SonarQube database/user. Reuses postgres-init by
# injecting the sonarqube spec into POSTGRES_INIT_SPECS for this run. SonarQube
# creates its own schema on first boot — only the (empty) DB + owner role are
# provisioned here. Idempotent; auto-run by `lds up` for sonarqube/all.
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [ -f .env ]; then
  while IFS='=' read -r k v; do
    k="${k%$'\r'}"
    case "$k" in ''|'#'*) continue ;; esac
    [ -z "${!k:-}" ] && export "$k=${v%$'\r'}"
  done < .env
fi

db="${SONARQUBE_POSTGRES_DB:-lds_sonarqube}"
u="${SONARQUBE_POSTGRES_USER:-app}"
p="${SONARQUBE_POSTGRES_PASSWORD:-app}"
spec="${db}:${u}:${p}"

merged="${POSTGRES_INIT_SPECS:-}"
if [ -n "$merged" ]; then
  merged="${merged},${spec}"
else
  merged="${spec}"
fi

# Deduplicate repeated specs while preserving order.
dedup=""
IFS=',' read -ra specs <<< "$merged"
for s in "${specs[@]}"; do
  s="$(printf '%s' "$s" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -z "$s" ] && continue
  case ",$dedup," in
    *",$s,"*) ;;
    *) dedup="${dedup:+$dedup,}$s" ;;
  esac
done

POSTGRES_INIT_SPECS="$dedup" "$ROOT/scripts/run/postgres-init.sh"

# --- reconcile the admin password with .env ---------------------------------
# A scanner token needs an admin login, and 26.10 removed password basic auth
# (form login + session cookie + X-XSRF-TOKEN header are required). If the DB
# still has the default 'admin' and SONAR_ADMIN_PASSWORD says something else,
# apply it now — that also skips the UI's forced first-login password change.
# The password policy needs 12+ chars incl. an uppercase letter for any custom
# value. Warn (never fail `up`) on drift.
base="http://127.0.0.1:${SONARQUBE_HOST_PORT:-4544}"
admin_user="${SONAR_ADMIN_USER:-admin}"
admin_pw="${SONAR_ADMIN_PASSWORD:-admin}"

status=""
for _ in $(seq 1 90); do
  status="$(curl -fsS --max-time 5 "$base/api/system/status" 2>/dev/null \
    | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([A-Z_]*\)".*/\1/p')" || true
  [ "$status" = "UP" ] && break
  sleep 2
done
if [ "$status" != "UP" ]; then
  echo "note: SonarQube is not answering yet — skipping the admin-password check (it runs again on the next:  lds up sonarqube)."
  exit 0
fi

jar="$(mktemp)"
login_xsrf=""
login() {  # $1 = password; leaves the session cookie jar in $jar on success
  local hdr code
  hdr="$(curl -sS -D - -o /dev/null -c "$jar" --max-time 15 -X POST \
    "$base/api/authentication/login" \
    --data-urlencode "login=${admin_user}" \
    --data-urlencode "password=$1" 2>/dev/null)" || true
  code="$(printf '%s' "$hdr" | tr -d '\r' \
    | sed -n 's/^HTTP\/[0-9.]*[[:space:]]*\([0-9]\{3\}\).*/\1/p' | head -n1)"
  login_xsrf="$(printf '%s' "$hdr" | tr -d '\r' \
    | sed -n 's/^[Xx]-[Xx][Ss][Rr][Ff]-[Tt][Oo][Kk][Ee][Nn]:[[:space:]]*\(.*\)$/\1/p' | head -n1)"
  [ "$code" = "200" ]
}

if login "$admin_pw"; then
  rm -f "$jar"
  echo "SonarQube: admin login '${admin_user}' verified."
  exit 0
fi
if [ "$admin_pw" != "admin" ] && login "admin"; then
  code="$(curl -sS -o /dev/null -w '%{http_code}' -b "$jar" \
    -H "X-XSRF-TOKEN: ${login_xsrf}" --max-time 15 -X POST \
    "$base/api/users/change_password" \
    --data-urlencode "login=${admin_user}" \
    --data-urlencode "previousPassword=admin" \
    --data-urlencode "password=${admin_pw}" 2>/dev/null)" || code="000"
  rm -f "$jar"
  if [ "$code" = "204" ] || [ "$code" = "200" ]; then
    echo "SonarQube: admin password set from SONAR_ADMIN_PASSWORD (was the default 'admin')."
  else
    echo "warning: SonarQube refused SONAR_ADMIN_PASSWORD (HTTP $code — the password policy needs 12+ chars incl. an uppercase letter)." >&2
    echo "         adjust it in .env and re-run:  lds up sonarqube" >&2
  fi
  exit 0
fi
rm -f "$jar"
echo "warning: could not log in as '${admin_user}' with SONAR_ADMIN_PASSWORD (nor with the default 'admin')." >&2
echo "         update SONAR_ADMIN_PASSWORD in .env to the current password, or restore admin/admin with:" >&2
echo "         lds tools sonar reset" >&2
exit 0
