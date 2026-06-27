# =============================================================================
# Base image: lds/rust-dev — Rust toolchain + cargo-watch (live reload).
# cargo-watch compiles from source, so baking it here is the biggest time-saver.
# =============================================================================
# Docker Hardened Image (DHI) dev flavor — Rust toolchain on Alpine (musl) + shell.
ARG DHI_REGISTRY=dhi.io
ARG RUST_VERSION=1.96
FROM ${DHI_REGISTRY}/rust:${RUST_VERSION}-alpine3.24-dev

# DHI defaults to a non-root user; cargo install + COPY below need root.
USER root

RUN cargo install cargo-watch --locked

# supercronic — container cron for cron-* templates (vendored amd64 from assets/,
# no network download; this base builds from the repo root — see docker-bake.hcl).
COPY assets/supersonic/v0.2.46/supercronic-linux-amd64 /usr/local/bin/supercronic
RUN chmod +x /usr/local/bin/supercronic

WORKDIR /app
