#!/usr/bin/env bash
# Build the shared base images (lds/*) via docker buildx bake (parallel).
#   build-bases.sh           # build/refresh all (uses layer cache)
#   build-bases.sh --force   # rebuild from scratch (--no-cache)
#   build-bases.sh --push    # build, then push to $REGISTRY (if set)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Load .env (single source of truth for versions). Precedence matches
# docker-compose: a var already set in the environment wins over .env, and
# .env wins over the built-in defaults below.
if [ -f .env ]; then
  while IFS='=' read -r key val; do
    case "$key" in ''|'#'*) continue ;; esac          # skip blanks/comments
    [ -z "${!key:-}" ] && export "$key=$val"           # don't clobber shell env
  done < .env
fi

export DHI_REGISTRY="${DHI_REGISTRY:-dhi.io}"
export PHP_VERSION="${PHP_VERSION:-8.4}"
export GO_VERSION="${GO_VERSION:-1.26}"
export RUST_VERSION="${RUST_VERSION:-1.96}"
export NODE_VERSION="${NODE_VERSION:-26.3}"
export PYTHON_VERSION="${PYTHON_VERSION:-3.14}"
export JAVA_VERSION="${JAVA_VERSION:-25}"
export NGINX_VERSION="${NGINX_VERSION:-1.27}"
REGISTRY="${REGISTRY:-}"

push=""; force=""
for a in "$@"; do
  [ "$a" = "--push" ]  && push=1
  [ "$a" = "--force" ] && force=1
done

bake_args=(--load)
[ -n "$force" ] && bake_args+=(--no-cache)

printf '\n========================================================\n'
printf   '  build-bases — building lds/* base images (buildx bake)\n'
printf   '========================================================\n'
docker buildx bake -f docker-bake.hcl "${bake_args[@]}"

# Push the registry copies as a separate step so the local lds/* tags (which
# have no registry) aren't pushed to docker.io by accident.
if [ -n "$push" ] && [ -n "$REGISTRY" ]; then
  for spec in "php:$PHP_VERSION" "go-dev:$GO_VERSION" "rust-dev:$RUST_VERSION" \
              "node-dev:$NODE_VERSION" "python-dev:$PYTHON_VERSION" "java-dev:$JAVA_VERSION" \
              "nginx:$NGINX_VERSION"; do
    echo "push $REGISTRY/$spec"
    docker tag "lds/$spec" "$REGISTRY/$spec"
    docker push "$REGISTRY/$spec"
  done
fi

printf '  ---- build-bases: done (lds/* ready) ----\n'
