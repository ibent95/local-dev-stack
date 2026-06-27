# =============================================================================
# Base image: lds/go-dev — Go toolchain + air (live reload) preinstalled.
# =============================================================================
# Docker Hardened Image (DHI) dev flavor — ships the Go toolchain + a shell.
ARG DHI_REGISTRY=dhi.io
ARG GO_VERSION=1.26
FROM ${DHI_REGISTRY}/golang:${GO_VERSION}-alpine3.24-dev

# DHI defaults to a non-root user; build steps below need root.
USER root

RUN go install github.com/air-verse/air@latest

# supercronic — container cron for cron-* templates (vendored amd64 from assets/,
# no network download; this base builds from the repo root — see docker-bake.hcl).
COPY assets/supersonic/v0.2.46/supercronic-linux-amd64 /usr/local/bin/supercronic
RUN chmod +x /usr/local/bin/supercronic

WORKDIR /app
