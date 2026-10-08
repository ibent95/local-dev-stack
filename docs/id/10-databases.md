# 10 · Mengisi database

## DB & user bawaan

`lds up` otomatis membuat database + user bawaan pada tiga engine utama
(jalankan manual dengan `lds db init [mysql|postgres|mongo|all]`):

- **MySQL** — database `app`, user `app`/`app` (`configs/mysql/init/`)
- **PostgreSQL** — database `app`, user `app`/`app` (`configs/postgres/init/`);
  DB tool (`lds_*`) ditambahkan via `POSTGRES_INIT_SPECS`
- **MongoDB** — replica set `rs0` + user `root`/`app` (via `mongo-init`)

Engine lain bersifat bawa-skema-sendiri: **MariaDB** (`mariadb:3306`),
**SQL Server** (`mssql:1433`, login `sa`) dan **Oracle** (`oracle:1521`, `SYS`/
`SYSTEM`) sudah terkonfigurasi dengan kredensial di `.env` — buat DB Anda
sendiri di dalamnya sesuai kebutuhan. Semuanya berbagi default `app`/`app`
bila berlaku.

## SQL init kustom

Letakkan berkas `.sql` di `configs/mysql/init/` atau `configs/postgres/init/` —
berkas dijalankan otomatis saat container **pertama** kali start (yaitu saat
volume data masih kosong).

Untuk menjalankannya ulang, hapus volume dulu: `./lds.sh down -v` lalu
`./lds.sh up`.

Dari container mana pun di `lds-network`, akses database lewat hostname:
`mysql:3306`, `mariadb:3306`, `postgres:5432`, `mssql:1433`, `oracle:1521`,
`mongo:27017`, `redis:6379`, `valkey:6379`, `memcached:11211`, `rabbitmq:5672`.
