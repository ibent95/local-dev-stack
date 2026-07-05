# =============================================================================
# docker-bake.hcl — build the shared lds/* base images in parallel.
# Driven by `./lds.sh build-bases` (adds --load / --no-cache, handles --push),
# or run directly:
#   docker buildx bake             # build all targets (into the local store)
#   docker buildx bake php         # one target
#   PHP_VERSION=8.3 docker buildx bake php   # override a version
# Versions come from env vars (PHP_VERSION, GO_VERSION, …) or the defaults here.
# =============================================================================
# DHI_REGISTRY = Docker Hardened Images namespace the dev bases build FROM.
# Language dev bases pin their own OS/flavor + `-dev` DHI suffix; lds/nginx uses
# the hardened runtime tag.
variable "DHI_REGISTRY"   { default = "dhi.io" }
variable "PHP_VERSION"    { default = "8.4" }
variable "GO_VERSION"     { default = "1.26" }
variable "RUST_VERSION"   { default = "1.96" }
variable "NODE_VERSION"   { default = "26.3" }
variable "PYTHON_VERSION" { default = "3.14" }
variable "JAVA_VERSION"   { default = "25" }
variable "NGINX_VERSION" { default = "1.27" }

group "default" {
  targets = ["php", "go-dev", "rust-dev", "node-dev", "python-dev", "java-dev", "nginx"]
}

# The ONE PHP base — context is the repo root so it can bake configs/php-app/*.
target "php" {
  context    = "."
  dockerfile = "base-images/php/Dockerfile"
  args       = { PHP_VERSION = "${PHP_VERSION}", DHI_REGISTRY = "${DHI_REGISTRY}" }
  tags       = ["lds/php:${PHP_VERSION}"]
}

# Dev bases use context = "." (repo root) so they can COPY the vendored
# assets/supersonic/* binary (supercronic), the same way the php target does.
target "go-dev" {
  context    = "."
  dockerfile = "base-images/go-dev/Dockerfile"
  args       = { GO_VERSION = "${GO_VERSION}", DHI_REGISTRY = "${DHI_REGISTRY}" }
  tags       = ["lds/go-dev:${GO_VERSION}"]
}

target "rust-dev" {
  context    = "."
  dockerfile = "base-images/rust-dev/Dockerfile"
  args       = { RUST_VERSION = "${RUST_VERSION}", DHI_REGISTRY = "${DHI_REGISTRY}" }
  tags       = ["lds/rust-dev:${RUST_VERSION}"]
}

target "node-dev" {
  context    = "."
  dockerfile = "base-images/node-dev/Dockerfile"
  args       = { NODE_VERSION = "${NODE_VERSION}", DHI_REGISTRY = "${DHI_REGISTRY}" }
  tags       = ["lds/node-dev:${NODE_VERSION}"]
}

target "python-dev" {
  context    = "."
  dockerfile = "base-images/python-dev/Dockerfile"
  args       = { PYTHON_VERSION = "${PYTHON_VERSION}", DHI_REGISTRY = "${DHI_REGISTRY}" }
  tags       = ["lds/python-dev:${PYTHON_VERSION}"]
}

target "java-dev" {
  context    = "."
  dockerfile = "base-images/java-dev/Dockerfile"
  args       = { JAVA_VERSION = "${JAVA_VERSION}", DHI_REGISTRY = "${DHI_REGISTRY}" }
  tags       = ["lds/java-dev:${JAVA_VERSION}"]
}

target "nginx" {
  context    = "."
  dockerfile = "base-images/nginx/Dockerfile"
  args       = { NGINX_VERSION = "${NGINX_VERSION}", DHI_REGISTRY = "${DHI_REGISTRY}" }
  tags       = ["lds/nginx:${NGINX_VERSION}"]
}
