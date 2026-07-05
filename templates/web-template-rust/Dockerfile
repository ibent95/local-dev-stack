# =============================================================================
# Rust web app — live reload via cargo-watch, from the shared base lds/rust-dev.
# =============================================================================
FROM lds/rust-dev:1.82
WORKDIR /app
COPY . .
EXPOSE 3000
CMD ["cargo", "watch", "-x", "run"]
