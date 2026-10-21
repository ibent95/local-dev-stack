#!/usr/bin/env bash
# Run a Semgrep scan and write SARIF for the viewer.  (lds tools semgrep [path])
#   default path = current directory. Results -> data/semgrep/reports/report.sarif,
#   viewed at http://semgrep.test (start the viewer: `lds up semgrep`).
#   lds tools semgrep clear removes the current report + metadata.
#
# Tightening knobs (all optional, set in .env or the shell):
#   SEMGREP_RULES     one or MORE rulesets, comma-separated — each becomes its
#                     own --config flag. E.g. p/default,p/security-audit or
#                     p/default,p/owasp-top-ten,p/cwe-top-25 (per-language packs
#                     like p/php, p/typescript can be mixed in too).
#   SEMGREP_SEVERITY  filter reported findings: comma list of INFO,WARNING,ERROR.
#   SEMGREP_ERROR=1   exit non-zero (1) when findings are reported — CI gating
#                     (the report is still written first).
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# Load .env so the SEMGREP_* vars are available (shell env still wins). Parse
# line-by-line (NOT `source`): .env holds unquoted multi-word values (e.g.
# PENPOT_FLAGS) that sourcing would try to execute as commands.
if [ -f "$ROOT/.env" ]; then
  while IFS='=' read -r k v; do
    k="${k%$'\r'}"
    case "$k" in ''|'#'*) continue ;; esac
    [ -z "${!k:-}" ] && export "$k=${v%$'\r'}"
  done < "$ROOT/.env"
fi

reports="$ROOT/data/semgrep/reports"
mkdir -p "$reports"

if [ "${1:-}" = "clear" ]; then
  rm -f "$reports/report.sarif" "$reports/scan-meta.json"
  echo "Cleared $reports/report.sarif and scan metadata."
  exit 0
fi

target="${1:-$PWD}"
# Resolve to an absolute path against the CALLER's cwd (we don't cd to $ROOT
# first, so a relative path is taken relative to where you ran the command).
target="$(cd "$target" 2>/dev/null && pwd)" || { echo "Target not found: ${1:-$PWD}"; echo "Pass a path to scan, e.g.  lds tools semgrep ~/projects/php/svc-setting-lumen"; exit 1; }

# Docker Desktop on Windows wants a Windows path for -v; convert under git-bash.
src="$target"; out="$reports"
if command -v cygpath >/dev/null 2>&1; then src="$(cygpath -w "$target")"; out="$(cygpath -w "$reports")"; fi

rules="${SEMGREP_RULES:-p/default,p/security-audit}"
# Build one --config per comma-separated ruleset (trim whitespace around each).
cfg_args=()
IFS=',' read -ra rulesets <<< "$rules"
for r in "${rulesets[@]}"; do
  r="$(printf '%s' "$r" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -n "$r" ] && cfg_args+=(--config "$r")
done
[ ${#cfg_args[@]} -gt 0 ] || cfg_args=(--config p/default)

# `auto` REQUIRES telemetry (it uploads project metadata to semgrep.dev to pick
# rules), so it can't run with metrics off. Every other config (p/…, a URL, or a
# local YAML) works with metrics OFF — which we prefer, because metrics-on's
# end-of-run upload hangs on slow/offline links (looks like the CLI never exits).
# So: metrics off by default; flip on ONLY when `auto` is among the rulesets.
metrics=off
for r in "${rulesets[@]}"; do
  r="$(printf '%s' "$r" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ "$r" = "auto" ] && metrics=on
done

# Optional severity filter (comma list of INFO,WARNING,ERROR → repeated flags).
sev_args=()
if [ -n "${SEMGREP_SEVERITY:-}" ]; then
  IFS=',' read -ra sevs <<< "$SEMGREP_SEVERITY"
  for s in "${sevs[@]}"; do
    s="$(printf '%s' "$s" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
    [ -n "$s" ] && sev_args+=(--severity "$s")
  done
fi

# Optional gating: SEMGREP_ERROR=1 → --error makes the CLI exit 1 on findings.
error_gate=0
case "${SEMGREP_ERROR:-}" in 1|true|TRUE|True|yes|on|y) error_gate=1 ;; esac
gate_args=(); [ "$error_gate" -eq 1 ] && gate_args=(--error)

# Static, unique container name (timestamp + 2 random digits) instead of Docker's
# random name — recognizable in `docker ps` and unique across concurrent runs.
name="lds-semgrep-scan-$(date +%Y%m%d%H%M%S)$(printf '%02d' $((RANDOM%100)))"
echo "Scanning $target with Semgrep (rules: $rules, metrics: $metrics${SEMGREP_SEVERITY:+, severity: $SEMGREP_SEVERITY}${error_gate:+, gating: on}) — container $name…"
set +e
docker run --rm --name "$name" -v "$src:/src" -v "$out:/out" -w /src \
  "${SEMGREP_IMAGE:-semgrep/semgrep}:${SEMGREP_VERSION:-1.181.0}" \
  semgrep scan --metrics "$metrics" "${cfg_args[@]}" "${sev_args[@]}" "${gate_args[@]}" --sarif --output /out/report.sarif
rc=$?
set -e

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
target_json="$(printf '%s' "$target" | sed 's/\\/\\\\/g; s/"/\\"/g')"
rules_json="$(printf '%s' "$rules" | sed 's/\\/\\\\/g; s/"/\\"/g')"
metrics_json="$(printf '%s' "$metrics" | sed 's/\\/\\\\/g; s/"/\\"/g')"
severity_json="$(printf '%s' "${SEMGREP_SEVERITY:-}" | sed 's/\\/\\\\/g; s/"/\\"/g')"
cat > "$reports/scan-meta.json" <<EOF
{"tool":"semgrep","mode":"fs","target":"$target_json","rules":"$rules_json","metrics":"$metrics_json","severity":"$severity_json","error_gate":$error_gate,"scanned_at":"$now"}
EOF

if [ "$rc" -ne 0 ]; then
  if [ "$error_gate" -eq 1 ] && [ "$rc" -eq 1 ]; then
    echo "Semgrep found issues (gating enabled — SEMGREP_ERROR=1) — exiting $rc."
    exit "$rc"
  fi
  echo "note: semgrep exited with code $rc — report may be incomplete."
fi

echo "Wrote $reports/report.sarif"
echo "View at http://${SEMGREP_HOST:-semgrep.test}  (run 'lds up semgrep' if the viewer isn't running)."
