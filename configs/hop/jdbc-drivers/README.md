# Hop — extra JDBC drivers

`apache/hop-web` bundles many JDBC drivers (Postgres, MSSQL, ClickHouse, SQLite,
DuckDB, …) but **not** the following, because they are GPL-licensed or have
restrictive redistribution terms:

| Driver | Why not bundled | Driver class |
|--------|----------------|---------------|
| **MySQL Connector/J** | GPL | `com.mysql.cj.jdbc.Driver` |
| **Oracle JDBC (ojdbc11)** | Oracle Free Use Terms | `oracle.jdbc.OracleDriver` |

Hop ships the MySQL *dialect* plugin, so the database type appears in the UI,
but connecting fails with:

```
Driver class 'com.mysql.cj.jdbc.Driver' could not be found
```

## Fix — download the driver jars here

The `hop` service single-file-mounts each jar into the container's shared jdbc
folder (`/usr/local/tomcat/jdbc-drivers`), adding them without hiding the bundled
drivers. Filenames are controlled by env vars in `.env`.

### MySQL Connector/J

```bash
curl -fsSL -o configs/hop/jdbc-drivers/mysql-connector-j-9.7.0.jar \
  https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/9.7.0/mysql-connector-j-9.7.0.jar
```

Env var: `HOP_MYSQL_DRIVER` (default: `mysql-connector-j-9.7.0.jar`).

### Oracle JDBC (ojdbc11)

```bash
curl -fsSL -o configs/hop/jdbc-drivers/ojdbc11-23.26.2.0.0.jar \
  https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc11/23.26.2.0.0/ojdbc11-23.26.2.0.0.jar
```

Env var: `HOP_ORACLE_DRIVER` (default: `ojdbc11-23.26.2.0.0.jar`).

### Recreate Hop after downloading

```bash
docker compose --profile hop up -d --force-recreate hop
```

To use a different version, change the filename **and** the matching env var
(`HOP_MYSQL_DRIVER` or `HOP_ORACLE_DRIVER`) in `.env`.

### Adding more drivers

Drop any GPL/non-bundled driver jar here and add a matching single-file mount
in the compose `hop` service volumes, following the same pattern.

> The jars themselves are git-ignored (don't commit redistribution-restricted
> drivers). Each developer fetches them with the commands above.
