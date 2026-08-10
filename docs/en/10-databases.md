# 10 · Seeding databases

## Default DBs & users

`lds up` auto-creates the default database + user on the three primary engines
(run them manually with `lds db init [mysql|postgres|mongo|all]`):

- **MySQL** — database `app`, user `app`/`app` (`configs/mysql/init/`)
- **PostgreSQL** — database `app`, user `app`/`app` (`configs/postgres/init/`);
  tool DBs (`lds_*`) are added via `POSTGRES_INIT_SPECS`
- **MongoDB** — replica set `rs0` + `root`/`app` users (via `mongo-init`)

The other engines are bring-your-own schema: **MariaDB** (`mariadb:3306`),
**SQL Server** (`mssql:1433`, `sa` login) and **Oracle** (`oracle:1521`, `SYS`/
`SYSTEM`) are pre-configured with the credentials in `.env` — create your own
DBs inside them as needed. All share the same `app`/`app` defaults where
applicable.

## Custom init SQL

Drop `.sql` files into `configs/mysql/init/` or `configs/postgres/init/` — they
run automatically on the **first** container start (i.e. when the data volume is
empty).

To re-run them, wipe the volume first: `./lds.sh down -v` then `./lds.sh up`.

From any container on `lds-network`, reach the databases by hostname:
`mysql:3306`, `mariadb:3306`, `postgres:5432`, `mssql:1433`, `oracle:1521`,
`mongo:27017`, `redis:6379`, `valkey:6379`, `memcached:11211`.
