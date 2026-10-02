# DuckDB — persistent file-based database engine, no network server.
# Builds FROM lds/duckdev (DHI alpine-base + DuckDB CLI binary).
# The data.duckdb file lives on a persistent volume shared with DBX.
# Query via:
#   docker exec -it lds-duckdb duckdb /data/data.duckdb
#   docker exec lds-duckdb duckdb -c "SELECT ..." /data/data.db
FROM lds/duckdev:${DUCKDB_VERSION:-1.2.0}

VOLUME ["/data"]
WORKDIR /data

# Keep container running; no network server to serve.
CMD ["sh", "-c", "tail -f /dev/null"]
