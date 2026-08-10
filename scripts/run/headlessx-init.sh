#!/usr/bin/env bash
# Ensure the HeadlessX source checkout exists (clone on first run, fast-forward
# update afterwards) so the headlessx-* compose services can build from it.
# Idempotent; auto-run by `lds up` for the headlessx/all profile.
#   ./lds.sh headlessx init     (same as the up auto-run)
#   ./lds.sh headlessx update   (explicit fetch + fast-forward)
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

URL="${HEADLESSX_REPO_URL:-https://github.com/saifyxpro/HeadlessX}"
REF="${HEADLESSX_REPO_REF:-main}"
DIR_VAL="${HEADLESSX_REPO_PATH:-./data/headlessx}"
case "$DIR_VAL" in
  /*) DIR="$DIR_VAL" ;;
  *) DIR="$ROOT/$DIR_VAL" ;;
esac

mkdir -p "$(dirname "$DIR")"

if [ ! -d "$DIR/.git" ]; then
  echo "Cloning HeadlessX ($URL @ $REF) into $DIR …"
  git clone --depth 1 --branch "$REF" "$URL" "$DIR"
  echo "HeadlessX checkout ready at $DIR"
else
  echo "Updating HeadlessX checkout at $DIR (ref: $REF) …"
  ( cd "$DIR"
    git fetch --depth 1 origin "$REF" 2>/dev/null || git fetch origin "$REF"
    if git merge-base --is-ancestor FETCH_HEAD HEAD 2>/dev/null; then
      echo "  Already up to date."
    elif git merge --ff-only FETCH_HEAD >/dev/null 2>&1; then
      echo "  Updated to origin/$REF."
    else
      echo "  Local checkout diverged — skipping auto-update."
      echo "  Resolve or reset it, then run: lds headlessx update"
    fi
  )
fi

# Windows git (core.autocrlf=true) checks this repo's LF files out as CRLF
# because it ships no .gitattributes. A CRLF shebang (#!/bin/sh\r) inside the
# container makes exec fail with "not found" (exit 127), crash-looping the
# headlessx-api/worker containers. Force the checkout to keep upstream's LF
# endings for the infra scripts that are baked into the images.
( cd "$DIR"
  git config core.autocrlf false
  find infra -name '*.sh' -delete
  git checkout -- infra
)
