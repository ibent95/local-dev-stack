# Shared JDBC drivers — central JAR directory

This directory holds JDBC driver JARs that are **not bundled** in the upstream
images (due to licensing or version pinning). Any service that needs a JDBC
driver mounts from here as a single-file volume — see `docker-compose.yml` for
the per-service mount points.

All JARs are git-ignored (don't commit redistribution-restricted binaries).
Each developer downloads the drivers they need with the `curl` commands below.

## Available drivers

| Driver | Filename | License | Maven coordinates |
|:-------|:---------|:--------|:------------------|
| **MySQL Connector/J** | `mysql-connector-j-*.jar` | GPL v2 | `com.mysql:mysql-connector-j` |
| **MariaDB JDBC** | `mariadb-java-client-*.jar` | LGPL 2.1 | `org.mariadb.jdbc:mariadb-java-client` |
| **Oracle JDBC (ojdbc11)** | `ojdbc11-*.jar` | Oracle Free Use Terms | `com.oracle.database.jdbc:ojdbc11` |
| **Microsoft SQL Server** | `mssql-jdbc-*.jre11.jar` | MIT | `com.microsoft.sqlserver:mssql-jdbc` |
| **PostgreSQL** | `postgresql-*.jar` | BSD-2-Clause | `org.postgresql:postgresql` |
| **Trino** | `trino-jdbc-*.jar` | Apache 2.0 | `io.trino:trino-jdbc` |

## Download commands

Run **once** after cloning the repo:

### MySQL Connector/J

```bash
curl -fsSL -o assets/jdbc/mysql-connector-j-9.7.0.jar \
  https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/9.7.0/mysql-connector-j-9.7.0.jar
```

**Env var:** `HOP_MYSQL_DRIVER` (default: `mysql-connector-j-9.7.0.jar`)
**Driver class:** `com.mysql.cj.jdbc.Driver`
**Used by:** Hop

### MariaDB JDBC

```bash
curl -fsSL -o assets/jdbc/mariadb-java-client-3.5.9.jar \
  https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/3.5.9/mariadb-java-client-3.5.9.jar
```

**Env var:** `HOP_MARIADB_DRIVER` (default: `mariadb-java-client-3.5.9.jar`)
**Driver class:** `org.mariadb.jdbc.Driver`
**Used by:** Hop

### Oracle JDBC (ojdbc11)

```bash
curl -fsSL -o assets/jdbc/ojdbc11-23.26.2.0.0.jar \
  https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc11/23.26.2.0.0/ojdbc11-23.26.2.0.0.jar
```

**Env var:** `HOP_ORACLE_DRIVER` (default: `ojdbc11-23.26.2.0.0.jar`)
**Driver class:** `oracle.jdbc.OracleDriver`
**Used by:** Hop

### Microsoft SQL Server JDBC

```bash
curl -fsSL -o assets/jdbc/mssql-jdbc-12.8.1.jre11.jar \
  https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.8.1.jre11/mssql-jdbc-12.8.1.jre11.jar
```

**Env var:** `HOP_MSSQL_DRIVER` (default: `mssql-jdbc-12.8.1.jre11.jar`)
**Driver class:** `com.microsoft.sqlserver.jdbc.SQLServerDriver`
**Used by:** Hop

### PostgreSQL JDBC

```bash
curl -fsSL -o assets/jdbc/postgresql-42.7.4.jar \
  https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.4/postgresql-42.7.4.jar
```

**Env vars:**
- `HOP_POSTGRESQL_DRIVER` (default: `postgresql-42.7.4.jar`) — Hop (override bundled version)
- `HIVE_METASTORE_POSTGRES_DRIVER` (default: `postgresql-42.7.4.jar`) — Hive Metastore

**Driver class:** `org.postgresql.Driver`
**Used by:** Hop, Hive Metastore

### Trino JDBC

```bash
curl -fsSL -o assets/jdbc/trino-jdbc-483.jar \
  https://repo1.maven.org/maven2/io/trino/trino-jdbc/483/trino-jdbc-483.jar
```

**Env var:** `HOP_TRINO_DRIVER` (default: `trino-jdbc-483.jar`)
**Driver class:** `io.trino.jdbc.TrinoDriver`
**JDBC URL:** `jdbc:trino://trino:8080/{catalog}/{schema}`
**Used by:** Hop

## Adding a new driver

1. Download the JAR into this directory
2. Add a matching single-file volume mount in the consuming service's `volumes:` block
3. Add an env var with a sensible default in `.env.example`
4. Add the download command to this README

## Upgrading a driver version

1. Download the new JAR into this directory with the new name
2. Update the matching env var(s) in `.env` to point to the new filename
3. Recreate the consuming container(s):
   ```bash
   docker compose up -d --force-recreate <service-name>
   ```

> The old JAR file will remain in this directory — delete it manually once you
> confirm the new version works.
