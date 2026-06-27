# 10 · Seeding databases

Drop `.sql` files into `configs/mysql/init/` or `configs/postgres/init/` — they
run automatically on the **first** container start (i.e. when the data volume is
empty).

To re-run them, wipe the volume first: `./lds.sh down -v` then `./lds.sh up`.

From any container on `lds-network`, reach the databases by hostname:
`mysql:3306`, `postgres:5432`, `redis:6379`, `memcached:11211`.
