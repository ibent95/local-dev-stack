# =============================================================================
# Base image: lds/node-dev — pinned Node toolchain (single source of version).
# Per-project deps (tsx, express, etc.) install into the project; this base
# just fixes the Node version used across templates.
# =============================================================================
# Docker Hardened Image (DHI) dev flavor — pinned Node toolchain + shell.
ARG DHI_REGISTRY=dhi.io
ARG NODE_VERSION=26.3
FROM ${DHI_REGISTRY}/node:${NODE_VERSION}-alpine3.24-dev

# DHI defaults to a non-root user; the COPY/chmod below needs root.
USER root

# supercronic — container cron for cron-* templates (vendored amd64 from assets/,
# no network download; this base builds from the repo root — see docker-bake.hcl).
COPY assets/supersonic/v0.2.46/supercronic-linux-amd64 /usr/local/bin/supercronic
RUN chmod +x /usr/local/bin/supercronic

WORKDIR /app
