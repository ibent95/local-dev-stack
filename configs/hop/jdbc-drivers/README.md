# Hop — extra JDBC drivers

`apache/hop-web` bundles many JDBC drivers (Postgres, MSSQL, ClickHouse, SQLite,
DuckDB, …) but **not** the following, because they are GPL-licensed or have
restrictive redistribution terms:

<table>
<thead>
<tr>
<th>Driver</th>
<th>Why not bundled</th>
<th>Driver class</th>
</tr>
</thead>
<tbody>
<tr>
<td>**MySQL Connector/J**</td>
<td>GPL</td>
<td>`com.mysql.cj.jdbc.Driver`</td>
</tr>
<tr>
<td>**MariaDB JDBC**</td>
<td>LGPL</td>
<td>`org.mariadb.jdbc.Driver`</td>
</tr>
<tr>
<td>**Oracle JDBC (ojdbc11)**</td>
<td>Oracle Free Use Terms</td>
<td>`oracle.jdbc.OracleDriver`</td>
</tr>
<tr>
<td>**Microsoft SQL Server JDBC**</td>
<td>Microsoft EULA</td>
<td>`com.microsoft.sqlserver.jdbc.SQLServerDriver`</td>
</tr>
</tbody>
</table>

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

### MariaDB JDBC

```bash
curl -fsSL -o configs/hop/jdbc-drivers/mariadb-java-client-3.5.9.jar \
  https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/3.5.9/mariadb-java-client-3.5.9.jar
```

Env var: `HOP_MARIADB_DRIVER` (default: `mariadb-java-client-3.5.9.jar`).

### Oracle JDBC (ojdbc11)

```bash
curl -fsSL -o configs/hop/jdbc-drivers/ojdbc11-23.26.2.0.0.jar \
  https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc11/23.26.2.0.0/ojdbc11-23.26.2.0.0.jar
```

Env var: `HOP_ORACLE_DRIVER` (default: `ojdbc11-23.26.2.0.0.jar`).

### Microsoft SQL Server JDBC

```bash
curl -fsSL -o configs/hop/jdbc-drivers/mssql-jdbc-12.8.1.jre11.jar \
  https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.8.1.jre11/mssql-jdbc-12.8.1.jre11.jar
```

Env var: `HOP_MSSQL_DRIVER` (default: `mssql-jdbc-12.8.1.jre11.jar`).

### PostgreSQL JDBC

```bash
curl -fsSL -o configs/hop/jdbc-drivers/postgresql-42.7.4.jar \
  https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.4/postgresql-42.7.4.jar
```

Env var: `HOP_POSTGRESQL_DRIVER` (default: `postgresql-42.7.4.jar`).

### Recreate Hop after downloading

```bash
docker compose --profile hop up -d --force-recreate hop
```

To use a different version, change the filename **and** the matching env var
(`HOP_MYSQL_DRIVER`, `HOP_MARIADB_DRIVER`, `HOP_ORACLE_DRIVER`, `HOP_MSSQL_DRIVER`,
or `HOP_POSTGRESQL_DRIVER`) in `.env`.

### Adding more drivers

Drop any GPL/non-bundled driver jar here and add a matching single-file mount
in the compose `hop` service volumes, following the same pattern.

> The jars themselves are git-ignored (don't commit redistribution-restricted
> drivers). Each developer fetches them with the commands above.
