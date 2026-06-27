# Hop — extra JDBC drivers

`apache/hop-web` bundles many JDBC drivers (Postgres, MSSQL, ClickHouse, SQLite,
DuckDB, …) but **not MySQL Connector/J**, because it's GPL-licensed and can't be
redistributed in the image. Hop ships the MySQL *dialect* plugin, so the database
type appears in the UI, but connecting fails with:

```
Driver class 'com.mysql.cj.jdbc.Driver' could not be found
```

## Fix — drop the driver jar here

The `hop` service single-file-mounts this jar into the container's shared jdbc
folder (`/usr/local/tomcat/jdbc-drivers`), adding it without hiding the bundled
drivers. The filename is the `HOP_MYSQL_DRIVER` value in `.env`.

Download once (works on any platform):

```bash
curl -fsSL -o configs/hop/jdbc-drivers/mysql-connector-j-9.7.0.jar \
  https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/9.7.0/mysql-connector-j-9.7.0.jar
```

Then recreate Hop so it loads the driver at startup:

```bash
docker compose --profile hop up -d --force-recreate hop
```

To use a different version, change the filename above **and** `HOP_MYSQL_DRIVER`
in `.env` so they match. Add any other GPL/non-bundled drivers (e.g. Oracle) the
same way — drop the jar here and add a matching single-file mount in the compose
`hop` service.

> The jars themselves are git-ignored (don't commit redistribution-restricted
> drivers). Each developer fetches them with the command above.
