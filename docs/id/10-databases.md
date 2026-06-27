# 10 · Mengisi database

Letakkan berkas `.sql` di `configs/mysql/init/` atau `configs/postgres/init/` —
berkas dijalankan otomatis saat container **pertama** kali start (yaitu saat
volume data masih kosong).

Untuk menjalankannya ulang, hapus volume dulu: `./lds.sh down -v` lalu
`./lds.sh up`.

Dari container mana pun di `lds-network`, akses database lewat hostname:
`mysql:3306`, `postgres:5432`, `redis:6379`, `memcached:11211`.
