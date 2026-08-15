#!/usr/bin/env bash
# =============================================================================
# Sync .env to .env.example — keep YOUR values, match the example's variables
# and ordering.
#
#   lds env-sync             rewrite .env so it mirrors .env.example
#   lds env-sync --dry-run   show what would change without writing anything
#   lds env-sync --quiet     suppress the "no changes" message (used by `up`)
#
# Rules:
#   * Every variable in .env.example must exist in .env at the same position.
#   * YOUR value wins: the value is kept from .env. Inline comments follow
#     .env.example, so the comments stay in sync when the example changes
#     (a '#' only starts a comment when preceded by whitespace, so values
#     like PASSWORD=abc#def are never touched).
#   * Variables missing from .env are added with the example's default value.
#   * Variables that only exist in .env (dropped from the example) are kept,
#     appended at the end under a marker comment — nothing is ever deleted.
#   * Structure (standalone comments / blank lines / order) follows
#     .env.example, so standalone comments you added to .env are not carried
#     over — edit .env.example if you want to change the structure.
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EXAMPLE="$ROOT/.env.example"
ENV_FILE="$ROOT/.env"

DRY=0
QUIET=0
for a in "$@"; do
  case "$a" in
    --dry-run|-n) DRY=1 ;;
    --quiet|-q)   QUIET=1 ;;
    -h|--help) echo "usage: lds env-sync [--dry-run] [--quiet]"; exit 0 ;;
    *) echo "env-sync: unknown argument '$a' (usage: lds env-sync [--dry-run] [--quiet])" >&2; exit 1 ;;
  esac
done

[ -f "$EXAMPLE" ] || { echo "env-sync: $EXAMPLE not found" >&2; exit 1; }
if [ ! -f "$ENV_FILE" ]; then
  if [ "$DRY" -eq 1 ]; then
    echo "env-sync: .env missing — dry run: would create it from .env.example"
  else
    cp "$EXAMPLE" "$ENV_FILE"
    echo "env-sync: no .env found — created from .env.example."
  fi
  exit 0
fi

# Match the example's line endings (the repo ships CRLF; keep whatever it uses).
EOL=$'\n'
if IFS= read -r first_line < "$EXAMPLE" && [[ "$first_line" == *$'\r' ]]; then
  EOL=$'\r\n'
fi

# --- Pass 1: index .env (key -> full line; first occurrence wins; keep order).
declare -A cur=()
order=()
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*= ]]; then
    k="${BASH_REMATCH[1]}"
    if [ -z "${cur[$k]+x}" ]; then
      cur[$k]="$line"
      order+=("$k")
    fi
  fi
done < "$ENV_FILE"

# --- Pass 2: rebuild from the example, substituting your values.
# Values stay yours; inline comments follow the example so .env comments stay
# in sync with .env.example. A '#' only starts a comment when preceded by
# whitespace, so values like PASSWORD=abc#def are never split.
out=""
added=()
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*= ]]; then
    k="${BASH_REMATCH[1]}"
    if [ -n "${cur[$k]+x}" ]; then
      user_line="${cur[$k]}"
      if [[ "$line" =~ ^(.*[^[:space:]])[[:space:]]+# ]]; then
        # Example carries an inline comment -> YOUR value + the example's
        # comment (spacing preserved), so the comment is always current.
        ex_val="${BASH_REMATCH[1]}"
        ex_comment="${line:${#BASH_REMATCH[1]}}"
        if [[ "$user_line" =~ ^(.*[^[:space:]])[[:space:]]+# ]]; then
          user_val="${BASH_REMATCH[1]}"
        else
          user_val="$user_line"
        fi
        out+="${user_val}${ex_comment}${EOL}"
      elif [[ "$user_line" =~ ^(.*[^[:space:]])[[:space:]]+# ]]; then
        # Example has no inline comment -> drop the stale user comment.
        out+="${BASH_REMATCH[1]}${EOL}"
      else
        out+="${user_line}${EOL}"
      fi
      unset 'cur[$k]'
    else
      out+="$line$EOL"
      added+=("$k")
    fi
  else
    out+="$line$EOL"
  fi
done < "$EXAMPLE"

# --- Pass 3: .env-only variables (not in the example) — append, never drop.
extra=()
for k in "${order[@]}"; do
  if [ -n "${cur[$k]+x}" ]; then
    extra+=("$k")
    if [ ${#extra[@]} -eq 1 ]; then
      out+="$EOL# --- kept from .env (not in .env.example) ---$EOL"
    fi
    out+="${cur[$k]}$EOL"
  fi
done

# --- Apply.
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
printf '%s' "$out" > "$tmp"

if cmp -s "$tmp" "$ENV_FILE"; then
  [ "$QUIET" -eq 1 ] || echo "env-sync: no changes — .env already matches .env.example (values untouched)."
  exit 0
fi

if [ "$DRY" -eq 1 ]; then
  echo "env-sync: DRY RUN — .env would be rewritten to match .env.example:"
  if command -v diff >/dev/null 2>&1; then
    diff -u "$ENV_FILE" "$tmp" || true
  fi
else
  cat "$tmp" > "$ENV_FILE"
  echo "env-sync: synced .env to .env.example (values kept)."
fi
[ ${#added[@]} -gt 0 ] && echo "  + added from example: ${added[*]}"
[ ${#extra[@]} -gt 0 ] && echo "  = kept (in .env only, appended at end): ${extra[*]}"
