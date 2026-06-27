# =============================================================================
# dev  : live reload via cargo-watch, from the shared base lds/rust-dev.
# prod : slim release binary.
# =============================================================================
FROM lds/rust-dev:1.82 AS dev
WORKDIR /app
COPY . .
EXPOSE 3000
CMD ["cargo", "watch", "-x", "run"]

FROM rust:1.82-bookworm AS builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim AS prod
COPY --from=builder /app/target/release/rust /usr/local/bin/rust
EXPOSE 3000
CMD ["rust"]
