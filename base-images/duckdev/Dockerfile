# =============================================================================
# Base image: lds/duckdev — DuckDB CLI + persistent data engine.
# DHI publishes no DuckDB image. DuckDB produces NO musl/Alpine binary (only
# glibc), and the glibc binary cannot run on Alpine even with gcompat (missing
# __res_init and other glibc symbols beyond gcompat's scope). Alpine repos also
# carry no duckdb package. Therefore this base uses Debian 13 slim — the same
# OS family as lds/php, which also builds FROM debian:13-slim (not a DHI image,
# since DHI doesn't publish generic Debian bases).
#
# The official DuckDB CLI binary is VENDORED under assets/duckdb/ (like the
# supercronic binary in assets/supersonic/) because GitHub release downloads
# fail unreliably under buildkit's HTTP stack. Download once:
#   curl -fsSL https://github.com/duckdb/duckdb/releases/download/v1.2.0/duckdb_cli-linux-amd64.zip \
#     -o /tmp/d.zip && unzip /tmp/d.zip -d assets/duckdb/ && rm /tmp/d.zip
#
# Context is the repo root so it can COPY assets/ (see docker-bake.hcl).
# No network port — DuckDB is embedded (like SQLite); the container holds the
# CLI + the data.duckdb file on a persistent volume shared with DBGate.
# =============================================================================
ARG DUCKDB_VERSION=1.2.0
FROM debian:13-slim

COPY assets/duckdb/duckdb /usr/local/bin/duckdb
RUN chmod +x /usr/local/bin/duckdb

WORKDIR /data
