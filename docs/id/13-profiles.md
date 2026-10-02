# 13 · Profile

Setiap grup layanan berada di belakang sebuah **profile** Compose, sehingga
`docker compose` (dan `lds up`) hanya menjalankan yang Anda minta. Halaman ini
menjelaskan tiap profile secara rinci: apa yang dijalankan, image dan port yang
terlibat, kredensial, volume, dan kapan Anda mengaktifkannya.

## Cara profile dipilih

- **Eksplisit:** `lds up <profile> [<profile> …]` menjalankan tepat itu saja,
  mengabaikan toggle di bawah. Mis. `lds up kafka` atau `lds up mysql redis`.
- **Set default:** `lds up` **tanpa argumen** menjalankan setiap profile yang
  toggle `LDS_ENABLE_<PROFILE>=true`-nya disetel di `.env`. Default: `proxy`,
  `php`, `mysql`, `dbx` aktif; selain itu mati. Jika semua toggle
  `false` → jatuh ke `all`.
- Satu layanan bisa termasuk beberapa profile. `proxy` + `dns` termasuk dalam
  **kedua** profile `proxy` dan `php`, jadi mengaktifkan `php` otomatis ikut
  membawa proxy dan DNS.

<table>
<thead>
<tr>
<th>Profile</th>
<th>Toggle `.env`</th>
<th>Default</th>
<th>Layanan yang dijalankan</th>
</tr>
</thead>
<tbody>
<tr>
<td>`proxy`</td>
<td>`LDS_ENABLE_PROXY`</td>
<td>✅</td>
<td>`proxy`, `dns`</td>
</tr>
<tr>
<td>`php`</td>
<td>`LDS_ENABLE_PHP`</td>
<td>✅</td>
<td>`php`, `proxy`, `dns`</td>
</tr>
<tr>
<td>`mysql`</td>
<td>`LDS_ENABLE_MYSQL`</td>
<td>✅</td>
<td>`mysql`</td>
</tr>
<tr>
<td>`mariadb`</td>
<td>`LDS_ENABLE_MARIADB`</td>
<td>❌</td>
<td>`mariadb` — fork kompatibel MySQL; juga database ERPNext</td>
</tr>
<tr>
<td>`mssql`</td>
<td>`LDS_ENABLE_MSSQL`</td>
<td>❌</td>
<td>`mssql` — SQL Server 2025 Developer (gratis untuk dev; password SA harus memenuhi kebijakan)</td>
</tr>
<tr>
<td>`oracle`</td>
<td>`LDS_ENABLE_ORACLE`</td>
<td>❌</td>
<td>`oracle` — Oracle Database Free 23ai (tanpa akun Oracle berkat mirror gvenzl)</td>
</tr>
<tr>
<td>`postgres`</td>
<td>`LDS_ENABLE_POSTGRES`</td>
<td>❌</td>
<td>`postgres`</td>
</tr>
<tr>
<td>`mongo`</td>
<td>`LDS_ENABLE_MONGO`</td>
<td>❌</td>
<td>`mongo`</td>
</tr>
<tr>
<td>`redis`</td>
<td>`LDS_ENABLE_REDIS`</td>
<td>❌</td>
<td>`redis`</td>
</tr>
<tr>
<td>`valkey`</td>
<td>`LDS_ENABLE_VALKEY`</td>
<td>❌</td>
<td>`valkey`</td>
</tr>
<tr>
<td>`memcached`</td>
<td>`LDS_ENABLE_MEMCACHED`</td>
<td>❌</td>
<td>`memcached`</td>
</tr>
<tr>
<td>`kafka`</td>
<td>`LDS_ENABLE_KAFKA`</td>
<td>❌</td>
<td>`kafka-controller`, `kafka-broker`, `schema-registry`, `connect-debezium`, `connect-generic`, `kafka-ui`</td>
</tr>
<tr>
<td>`phpcacheadmin`</td>
<td>`LDS_ENABLE_PHPCACHEADMIN`</td>
<td>❌</td>
<td>`phpcacheadmin`</td>
</tr>
<tr>
<td>`dbx`</td>
<td>`LDS_ENABLE_DBX`</td>
<td>✅</td>
<td>`dbx`</td>
</tr>
<tr>
<td>`soketi`</td>
<td>`LDS_ENABLE_SOKETI`</td>
<td>❌</td>
<td>`soketi`</td>
</tr>
<tr>
<td>`centrifugo`</td>
<td>`LDS_ENABLE_CENTRIFUGO`</td>
<td>❌</td>
<td>`centrifugo`</td>
</tr>
<tr>
<td>`mqtt`</td>
<td>`LDS_ENABLE_MQTT`</td>
<td>❌</td>
<td>`mosquitto`, `mqttx`</td>
</tr>
<tr>
<td>`drawdb`</td>
<td>`LDS_ENABLE_DRAWDB`</td>
<td>❌</td>
<td>`drawdb` — perancang skema DB (buka di `localhost:4502`)</td>
</tr>
<tr>
<td>`hop`</td>
<td>`LDS_ENABLE_HOP`</td>
<td>❌</td>
<td>`hop` — Apache Hop Web (perancang ETL)</td>
</tr>
<tr>
<td>`superset`</td>
<td>`LDS_ENABLE_SUPERSET`</td>
<td>❌</td>
<td>`superset` — Apache Superset (BI)</td>
</tr>
<tr>
<td>`semgrep`</td>
<td>`LDS_ENABLE_SEMGREP`</td>
<td>❌</td>
<td>`semgrep` — viewer SARIF (`lds tools semgrep` menjalankan scan)</td>
</tr>
<tr>
<td>`zap`</td>
<td>`LDS_ENABLE_ZAP`</td>
<td>❌</td>
<td>`zap` — pemindai DAST OWASP ZAP, UI browser di `zap.test` (:4510 UI, :4512 proxy/API)</td>
</tr>
<tr>
<td>`trivy`</td>
<td>`LDS_ENABLE_TRIVY`</td>
<td>❌</td>
<td>`trivy` — viewer laporan di `trivy.test` (`lds tools trivy` menjalankan scan)</td>
</tr>
<tr>
<td>`crg`</td>
<td>`LDS_ENABLE_CRG`</td>
<td>❌</td>
<td>`crg` — viewer code-review-graph di `crg.test` (`lds tools crg &lt;path&gt;` menjalankan scan)</td>
</tr>
<tr>
<td>`analytics`</td>
<td>`LDS_ENABLE_ANALYTICS`</td>
<td>❌</td>
<td>`analytics-api`, `analytics-ui` — Nuxt/Vue reactive analytics</td>
</tr>
<tr>
<td>`vaultwarden`</td>
<td>`LDS_ENABLE_VAULTWARDEN`</td>
<td>❌</td>
<td>`vaultwarden` — password manager</td>
</tr>
<tr>
<td>`mail`</td>
<td>`LDS_ENABLE_MAIL`</td>
<td>❌</td>
<td>`mailpit` — local SMTP sink + web inbox</td>
</tr>
<tr>
<td>`penpot`</td>
<td>`LDS_ENABLE_PENPOT`</td>
<td>❌</td>
<td>`penpot-frontend`, `penpot-backend`, `penpot-exporter` — collaborative design</td>
</tr>
<tr>
<td>`instatic`</td>
<td>`LDS_ENABLE_INSTATIC`</td>
<td>❌</td>
<td>`instatic` — visual CMS / website builder self-hosted di `instatic.test`</td>
</tr>
<tr>
<td>`duckdb`</td>
<td>`LDS_ENABLE_DUCKDB`</td>
<td>❌</td>
<td>`duckdb` — mesin OLAP embedded (CLI saja, exec ke container)</td>
</tr>
<tr>
<td>`trino`</td>
<td>`LDS_ENABLE_TRINO`</td>
<td>❌</td>
<td>`trino`, `hive-metastore` — mesin query SQL terdistribusi (image resmi)</td>
</tr>
<tr>
<td>`tasks`</td>
<td>`LDS_ENABLE_TASKS`</td>
<td>❌</td>
<td>`tasks-api`, `tasks-ui` — Angular project management</td>
</tr>
<tr>
<td>`wiki`</td>
<td>`LDS_ENABLE_WIKI`</td>
<td>❌</td>
<td>`wiki-api`, `wiki-ui` — Next.js documentation</td>
</tr>
<tr>
<td>`openwa`</td>
<td>`LDS_ENABLE_OPENWA`</td>
<td>❌</td>
<td>`openwa` — server API WhatsApp (reuse `postgres` + `redis` bersama)</td>
</tr>
<tr>
<td>`rustfs`</td>
<td>`LDS_ENABLE_RUSTFS`</td>
<td>❌</td>
<td>`rustfs` — berbagi file self-hosted (API + console)</td>
</tr>
<tr>
<td>`headlessx`</td>
<td>`LDS_ENABLE_HEADLESSX`</td>
<td>❌</td>
<td>`headlessx-api`, `headlessx-worker`, `headlessx-web`, `headlessx-html-to-md`, `headlessx-yt-engine` — automasi browser anti-deteksi (dibangun dari `data/headlessx`)</td>
</tr>
<tr>
<td>`playwright`</td>
<td>`LDS_ENABLE_PLAYWRIGHT`</td>
<td>❌</td>
<td>`playwright`, `playwright-report` — runner tes End-To-End (image resmi) + viewer laporan HTML</td>
</tr>
<tr>
<td>`erpnext`</td>
<td>`LDS_ENABLE_ERPNEXT`</td>
<td>❌</td>
<td>`erpnext-*` — paket ERP lengkap di atas Frappe, DB di `postgres` bersama (atau `mariadb` via `ERPNEXT_DB_TYPE`); **berat** (~3-6 GB RAM, pull multi-GB)</td>
</tr>
<tr>
<td>`all`</td>
<td>—</td>
<td>—</td>
<td>semua layanan di atas</td>
</tr>
</tbody>
</table>

> **Aplikasi kustom** (`analytics`, `tasks`, `wiki`), **tool data** (`drawdb`,
> `hop`, `superset`, `semgrep`, `zap`, `trivy`, `crg`, `vaultwarden`, `mail`,
> `penpot`, `instatic`, `openwa`, `rustfs`) serta **profile automasi/pengujian**
> (`headlessx`, `playwright`) punya halaman sendiri —
> lihat [15 · Dashboard & data tools](15-data-tools.md). Panel kontrol di
> `http://localhost` menautkan semuanya lengkap dengan status langsung.

---

## `proxy` — edge reverse proxy + DNS

**Menjalankan:** `proxy` + `dns`. **Toggle:** `LDS_ENABLE_PROXY`. **Aktif secara
default.**

Titik masuk untuk setiap URL `<nama>.test` proyek — didaftarkan paling awal
karena hampir semua hal lain dirutekan melaluinya. Ini adalah proxy + DNS **secara
mandiri**, tanpa container PHP, jadi inilah profile yang tepat untuk aplikasi
**non-PHP** (Go, Rust, Node, Java) yang butuh URL `<nama>.test` tanpa runtime PHP
ikut hidup.

- **`proxy`** — `nginxproxy/nginx-proxy` di port host `${WEB_HOST_PORT}` (default
  `80`). Mengawasi Docker socket dan merutekan `<nama>.test` ke container mana pun
  yang menyetel `VIRTUAL_HOST` (+ `VIRTUAL_PORT`). Inilah cara aplikasi tiap
  bahasa mendapat hostname.
- **`dns`** — `dnsmasq` (image dibangun lokal) di port host `${DNS_HOST_PORT}`
  (default `53`, udp + tcp). Meresolusi `*.test` → `127.0.0.1` sehingga folder/
  container proyek baru langsung dapat dijangkau tanpa edit file hosts.

> `proxy` + `dns` **dipakai bersama** dengan profile `php`, jadi mengaktifkan
> `php` sudah ikut membawanya — toggle `proxy` secara mandiri berarti saat `php`
> mati. TLD `.test` dirujuk di **kedua** `configs/nginx/default.conf` dan
> `configs/dns/dnsmasq.conf`; ubah di keduanya untuk memakai akhiran lain.
>
> **Default HTTP:** proxy melayani `http://` biasa. Untuk `https://*.test`,
> aktifkan overlay HTTPS opt-in (`lds certs` + `LDS_ENABLE_HTTPS=true`) — lihat
> catatan TLS di akhir halaman ini.

## `php` — hosting multi-proyek PHP ala Devilbox

**Menjalankan:** `php` + `proxy` + `dns`. **Toggle:** `LDS_ENABLE_PHP`. **Aktif
secara default.**

Layanan `php` menjalankan base image `lds/php:${PHP_VERSION}` — satu container
menjalankan `supervisord` → `php-fpm` + `nginx`. Ini adalah **mass virtual
host**: setiap folder di bawah `${PHP_PROJECTS_PATH}` otomatis dilayani di
`<folder>.test`, dengan docroot dideteksi otomatis berurutan `public/` >
`htdocs/` > root folder. Tanpa konfigurasi per-proyek — taruh folder, langsung
aktif.

- **Image:** `lds/php:${PHP_VERSION}` (default `8.4`) — dibangun sekali via
  `lds build-bases`. Sudah memuat php-fpm + nginx + composer + supervisor +
  supercronic.
- **Mount:** `${PHP_PROJECTS_PATH}` → `/var/www` (root mass-vhost yang live).
- **Toggle supervisord:** `ENABLE_PHP`, `ENABLE_NGINX` (keduanya aktif di sini),
  `ENABLE_CRON` (mati).
- `proxy` + `dns` bawaan (lihat di atas) memberi hostname `.test`. Container php
  adalah vhost **catch-all** (`localhost` + regex `*.test`), jadi request yang
  tidak diklaim `VIRTUAL_HOST` yang lebih spesifik akan jatuh ke sini.

**Gunakan saat** Anda mengembangkan aplikasi PHP (plain, Laravel, Symfony,
CodeIgniter, dll.). Lihat [06](06-php-multiproject.md).

## `mysql` — MySQL 8.4

**Menjalankan:** `mysql`. **Toggle:** `LDS_ENABLE_MYSQL`. **Aktif secara default.**

- **Image:** `mysql:${MYSQL_VERSION}` (default `8.4`).
- **Port:** host `${MYSQL_HOST_PORT}` (default `4400`) → container `3306`.
- **Kredensial:** root `${MYSQL_ROOT_PASSWORD}` (default `root`); user aplikasi
  `${MYSQL_USER}`/`${MYSQL_PASSWORD}` (default `app`/`app`) pada DB
  `${MYSQL_DATABASE}` (default `app`).
- **Siap CDC:** dijalankan dengan `--log-bin`, `--binlog-format=ROW`,
  `--binlog-row-image=FULL`, `--gtid-mode=ON` — Debezium langsung jalan.
- **Init:** SQL di `configs/mysql/init/` dijalankan saat boot pertama.
- **Volume:** `mysql-data` (bertahan antar restart; dihapus oleh `lds down -v`).

## `mariadb` — MariaDB 11.8

**Menjalankan:** `mariadb`. **Toggle:** `LDS_ENABLE_MARIADB`. **Mati secara
default.**

Fork kompatibel MySQL (image DHI yang di-hardening). Berjalan dengan **default
utf8mb4** (`--character-set-server=utf8mb4
--collation-server=utf8mb4_unicode_ci --skip-character-set-client-handshake`) —
persis yang dibutuhkan ERPNext, sehingga **ERPNext memakai ulang instance
bersama ini** (profile `erpnext` otomatis ikut membawa `mariadb`).

- **Image:** `mariadb:${MARIADB_VERSION}` (default `11.8-debian13`).
- **Port:** host `${MARIADB_HOST_PORT}` (default `4406`) → container `3306`.
- **Kredensial:** root `${MARIADB_ROOT_PASSWORD}` (default `root`); user aplikasi
  `${MARIADB_USER}`/`${MARIADB_PASSWORD}` (default `app`/`app`) pada DB
  `${MARIADB_DATABASE}` (default `app`).
- **Volume:** `mariadb-data`.

## `mssql` — Microsoft SQL Server 2025 (Developer)

**Menjalankan:** `mssql`. **Toggle:** `LDS_ENABLE_MSSQL`. **Mati secara default.**

Edisi Developer gratis untuk development/testing (`ACCEPT_EULA=Y` adalah
persetujuan lisensi). Dua syarat keras: **`MSSQL_SA_PASSWORD` harus memenuhi
kebijakan password SQL Server** (8+ karakter, 3 dari 4: huruf besar/kecil/angka/
simbol) atau server langsung keluar saat boot, dan **`MSSQL_MEM_LIMIT` harus
≥ 2g**.

- **Image:** `mcr.microsoft.com/mssql/server:${MSSQL_VERSION}` (default
  `2025-latest`, ~1.5 GB; skema Microsoft `<tahun>-latest` — mayor sebelumnya
  tetap tersedia sebagai `2022-latest`).
- **Port:** host `${MSSQL_HOST_PORT}` (default `4407`) → container `1433`.
- **Kredensial:** `sa` / `${MSSQL_SA_PASSWORD}` (default `Lds-dev-2024!`).
- **Volume:** `mssql-data`. Boot pertama menjalankan setup sebelum menerima koneksi.

## `oracle` — Oracle Database Free 23ai

**Menjalankan:** `oracle`. **Toggle:** `LDS_ENABLE_ORACLE`. **Mati secara default.**

Lisensi developer gratis via mirror **`gvenzl/oracle-free`** — tanpa akun/login
Oracle (image resmi `container-registry.oracle.com` membutuhkannya).
`ORACLE_PASSWORD` **wajib** dan mengatur `SYS`/`SYSTEM`; `ORACLE_DATABASE`
(default `FREE`) membuat PDB dengan nama itu.

- **Image:** `gvenzl/oracle-free:${ORACLE_VERSION}` (default `23.26.2-slim`, ~3 GB;
  di-pin ke 23.x terbaru yang didukung — pakai `23-slim` untuk mengambang di mayor).
- **Port:** host `${ORACLE_HOST_PORT}` (default `4408`) → `1521` (DB); konsol web
  EM Express di `https://localhost:4409/em`.
- **Kredensial:** `SYS`/`SYSTEM` dengan `${ORACLE_PASSWORD}` (default
  `Oracle-dev-2024!`); user aplikasi `${ORACLE_USER}` (default `app`).
- **Volume:** `oracle-data`. Boot pertama membuat DB (~1-2 menit, beberapa GB
  disk); container berjalan sebagai uid 54321 (chown `oracle-data` di Linux
  bila penulisan volume gagal).

## `postgres` — PostgreSQL 16

**Menjalankan:** `postgres`. **Toggle:** `LDS_ENABLE_POSTGRES`. **Mati secara
default.**

- **Image:** `postgres:${POSTGRES_VERSION}` (default `16-alpine`).
- **Port:** host `${POSTGRES_HOST_PORT}` (default `4401`) → container `5432`.
- **Kredensial:** `${POSTGRES_USER}`/`${POSTGRES_PASSWORD}` pada DB
  `${POSTGRES_DB}` (semua default `app`).
- **Siap CDC:** berjalan dengan `wal_level=logical`, `max_wal_senders=10`,
  `max_replication_slots=10` untuk replikasi logical Debezium.
- **Init:** SQL di `configs/postgres/init/` dijalankan saat boot pertama.
- **Volume:** `postgres-data`.

## `mongo` — MongoDB 7 (replica set node tunggal)

**Menjalankan:** `mongo`. **Toggle:** `LDS_ENABLE_MONGO`. **Mati secara default.**

- **Image:** `mongo:${MONGO_VERSION}` (default `7`).
- **Port:** host `${MONGO_HOST_PORT}` (default `4402`) → container `27017`.
- **Replica set:** berjalan sebagai replica set node-tunggal **`rs0`** dengan
  **keyfile auth** — wajib untuk change stream / Debezium CDC. Keyfile dibuat
  otomatis ke volume `mongo-config` (tanpa secret yang di-commit).
- **Bootstrap:** replica set diinisiasi dan user `root` / `app` dibuat oleh
  `scripts/run/mongo-init.*` (otomatis dijalankan `lds up` untuk `mongo`/`all`;
  idempotent) — **bukan** oleh `MONGO_INITDB_*`, yang tidak bisa membuat user di
  server ber-replSet.
- **Init:** `*.js` / `*.sh` di `configs/mongo/init/` dijalankan saat boot pertama.
- **Volume:** `mongo-data`, `mongo-config`.

## `redis` — Redis 7

**Menjalankan:** `redis`. **Toggle:** `LDS_ENABLE_REDIS`. **Mati secara default.**

- **Image:** `redis:${REDIS_VERSION}` (default `7-alpine`).
- **Port:** host `${REDIS_HOST_PORT}` (default `4403`) → container `6379`.
- **Konfigurasi:** `configs/redis/redis.conf` (di-mount read-only).
- **Volume:** `redis-data`.
- Inspeksi secara visual dengan profile `phpcacheadmin`.

## `valkey` — Valkey (kompatibel Redis)

**Menjalankan:** `valkey`. **Toggle:** `LDS_ENABLE_VALKEY`. **Mati secara default.**

- **Image:** `valkey/valkey:${VALKEY_VERSION}`.
- **Port:** host `${VALKEY_HOST_PORT}` (default `4405`) → container `6379`.
- **Storage:** appendonly persisten pada volume `valkey-data`.
- Kompatibel protokol Redis (drop-in cache/data store).

## `memcached` — Memcached 1.6

**Menjalankan:** `memcached`. **Toggle:** `LDS_ENABLE_MEMCACHED`. **Mati secara
default.**

- **Image:** `memcached:${MEMCACHED_VERSION}` (default `1.6-alpine`).
- **Port:** host `${MEMCACHED_HOST_PORT}` (default `4404`) → container `11211`.
- **Batas memori:** `${MEMCACHED_MEMORY}` MB (default `64`).
- **Tanpa volume** — murni in-memory; data hilang saat restart, memang disengaja.
- Inspeksi via profile `phpcacheadmin`.

## `kafka` — stack Kafka penuh (KRaft + Debezium CDC)

**Menjalankan:** `kafka-controller`, `kafka-broker`, `schema-registry`,
`connect-debezium`, `connect-generic`, `kafka-ui`. **Toggle:** `LDS_ENABLE_KAFKA`.
**Mati secara default.** Lihat [09](09-kafka-debezium.md) untuk panduan lengkap.

- **Mode KRaft** (tanpa ZooKeeper): **controller** khusus (node 1) dan **broker**
  (node 2), image `apache/kafka:${KAFKA_VERSION}`. Setel `KAFKA_CLUSTER_ID`
  *sebelum* start pertama — mengubahnya nanti berarti menghapus volume
  `kafka-*-data`.
  - Bootstrap broker: host `${KAFKA_HOST_PORT}` (default `4420`) → `29092`
    (EXTERNAL); client di dalam jaringan memakai `kafka-broker:9092` (INTERNAL).
- **`schema-registry`** — **Apicurio Registry** (Apache 2.0, in-memory) di host
  `${SCHEMA_REGISTRY_HOST_PORT}` (default `4421`). API kompatibel Confluent di
  `/apis/ccompat/v7`. Hanya dev: skema reset saat restart (didaftarkan ulang
  otomatis).
- **`connect-debezium`** — Kafka Connect pada image **Debezium** (connector
  source CDC MySQL + Postgres sudah terpaket). REST di `${CONNECT_HOST_PORT}`
  (default `4423`). JSON connector ada di `configs/kafka/connect/`.
- **`connect-generic`** — Kafka Connect pada image **apache/kafka vanilla**
  (runtime sama, **tanpa** connector bawaan). Taruh JAR plugin di
  `configs/kafka/connect-generic/plugins/`. REST di `${CONNECT_GENERIC_HOST_PORT}`
  (default `4422`). Memakai group + topik state sendiri agar tidak bentrok dengan
  worker Debezium.
- **`kafka-ui`** — Kafka UI kafbat di host `${KAFKA_UI_HOST_PORT}` (default
  `4424`), sudah terhubung ke broker, schema registry, dan kedua worker Connect.
- **Topik:** disediakan dari `${KAFKA_TOPICS}` oleh `scripts/run/kafka-topics.*`
  (otomatis dijalankan `lds up` untuk profile kafka, atau manual via
  `lds kafka-topics`).
- **Volume:** `kafka-controller-data`, `kafka-broker-data`.

## UI admin — `phpcacheadmin` dan `dbx`

Kedua UI admin web kini punya **profile masing-masing** sehingga dapat diaktifkan
secara independen (tidak ada lagi umbrella `tools`). Keduanya dijangkau via proxy
(`*.test`) **dan** port host langsung, dan hanya menampilkan data bila profile
data yang sesuai juga jalan.

> Untuk URL `.test` Anda juga perlu `proxy` (atau `php`) jalan; untuk data nyata,
> jalankan profile `mysql` / `postgres` / `redis` / `valkey` / `memcached` yang sesuai.

### `phpcacheadmin` — browser Redis + Valkey + Memcached

**Menjalankan:** `phpcacheadmin`. **Toggle:** `LDS_ENABLE_PHPCACHEADMIN`. **Mati
secara default** (aktifkan saat Anda menjalankan `redis`/`memcached`).

- Browser Redis + Valkey + Memcached + OPcache/APCu. `${CACHE_ADMIN_HOST}` (default
  `cache.test`) / host `${CACHE_ADMIN_HOST_PORT}` (default `4500`).
- Sudah diarahkan ke layanan `redis`, `valkey`, dan `memcached` — jalankan salah satu (atau
  keduanya) untuk melihat data. Tanpa volume (UI stateless).

### `dbx` — client DB web

**Menjalankan:** `dbx`. **Toggle:** `LDS_ENABLE_DBX`. **Aktif secara
default.**

- Client DB web untuk **100+ engine** (MySQL, MariaDB, Postgres, MongoDB, SQL
  Server, Oracle, Redis, DuckDB, …), lengkap dengan SQL editor, ER diagram dan
  server MCP. `${DB_ADMIN_HOST}` (default `db.test`) / host
  `${DB_ADMIN_HOST_PORT}` (default `4501`).
- **Terbuka secara default** — `DBX_DISABLE_PASSWORD=1` berarti tanpa halaman
  login (set `0` + `DBX_PASSWORD=…` di `.env` untuk mengunci UI). Tambah/edit/
  hapus koneksi bebas.
- MySQL + MariaDB + Postgres + MongoDB + SQL Server + Oracle stack otomatis
  terdaftar via `scripts/run/dbx-seed.*` (otomatis dijalankan `lds up`
  untuk profile `dbx`/`all`; script ini POST ke Web API DBX **setelah**
  container naik, dan dilewati bila koneksi sudah ada).
- Koneksi tersimpan di `dbx.db` di direktori bind-mount `data/dbx/`
  (bersama `.dbx/secret.key` — cadangkan keduanya sebagai pasangan).
- Image `t8y2/dbx` (Apache-2.0, upstream — bukan image DHI), dipin oleh
  `DBX_VERSION`, dibatasi mem oleh `DBX_MEM_LIMIT` (default `768m`).

## Broker realtime / pub-sub — `soketi`, `centrifugo`, `mqtt`

Ketiganya **mati secara default**, **stateless** (tanpa volume data → tanpa
penumpukan disk), dan **dibatasi mem/cpu**. Mereka berbicara protokol klien yang
**berbeda** dan **tidak** dapat saling tukar — pilih yang protokol kliennya cocok
dengan aplikasi Anda. Satu broker melayani channel/topik tak terbatas; Anda tidak
perlu instance kedua per channel.

### `soketi` — protokol Pusher

**Toggle:** `LDS_ENABLE_SOKETI`. Headless (tanpa UI).

- **Image:** `quay.io/soketi/soketi:${SOKETI_VERSION}`. Port host
  `${SOKETI_HOST_PORT}` (default `4440`) → `6001`; juga `${SOKETI_HOST}` (default
  `ws.test`) via proxy.
- Drop-in untuk **broadcasting Laravel** (`BROADCAST_DRIVER=pusher`/reverb) +
  **Laravel Echo** / `pusher-js`. Kredensial app: `${SOKETI_APP_ID}` /
  `${SOKETI_APP_KEY}` / `${SOKETI_APP_SECRET}` (default dev — ganti untuk yang
  dipakai bersama).
- Batas: `${SOKETI_MEM_LIMIT}` (default `256m`), `${SOKETI_CPUS}` (default `0.50`).

### `centrifugo` — channel WebSocket mentah + UI admin

**Toggle:** `LDS_ENABLE_CENTRIFUGO`.

- **Image:** `centrifugo/centrifugo:${CENTRIFUGO_VERSION}`. Port host
  `${CENTRIFUGO_HOST_PORT}` (default `4441`) → `8000`; UI admin di
  `${CENTRIFUGO_HOST}` (default `centrifugo.test`).
- Klien memakai **Centrifuge JS SDK** (bukan Echo). Berjalan dalam mode dev
  **insecure** (`--admin_insecure --client_insecure --api_insecure`) agar bisa
  pub/sub tanpa membuat JWT — matikan flag-nya untuk auth. Kunci:
  `${CENTRIFUGO_API_KEY}`, `${CENTRIFUGO_TOKEN_HMAC_SECRET_KEY}`, admin
  `${CENTRIFUGO_ADMIN_PASSWORD}`.
- Batas: `${CENTRIFUGO_MEM_LIMIT}` (default `256m`), `${CENTRIFUGO_CPUS}` (`0.50`).

### `mqtt` — broker Mosquitto + web client MQTTX

**Toggle:** `LDS_ENABLE_MQTT`. Profile ringan: broker + client UI di browser.

- **Image broker:** `eclipse-mosquitto:${MOSQUITTO_VERSION}`. Port:
  `${MQTT_HOST_PORT}` (default `4442`) → `1883` (MQTT native),
  `${MQTT_WS_HOST_PORT}` (default `4443`) → `9001` (MQTT-over-WebSocket, path `/`).
- **Image web client:** `emqx/mqttx-web:${MQTTX_VERSION}` di
  `${MQTT_HOST}` (default `mqtt.test`) / `${MQTTX_HOST_PORT}` (default `4444`).
- Klien tetap memakai **library MQTT** (MQTT.js / Paho di browser, MQTT native
  untuk backend). `mqttx` adalah UI client (publish/subscribe), bukan dashboard admin broker.
- Batas: `${MOSQUITTO_MEM_LIMIT}` (default `128m`), `${MQTTX_MEM_LIMIT}` (default `128m`).

## `vaultwarden` — password manager

**Menjalankan:** `vaultwarden`. **Toggle:** `LDS_ENABLE_VAULTWARDEN`. **Mati secara default.**

- **Image:** `vaultwarden/server:${VAULTWARDEN_VERSION}`.
- **UI/API:** `${VAULTWARDEN_HOST}` (default `vaultwarden.test`) dan host port
  `${VAULTWARDEN_HOST_PORT}` (default `4506`).
- **Storage:** volume persisten berbasis sqlite (`vaultwarden-data`).
- **Default:** signup nonaktif (`VAULTWARDEN_SIGNUPS_ALLOWED=false`);
  panel admin dilindungi `VAULTWARDEN_ADMIN_TOKEN`.

## `mail` — Mailpit (SMTP lokal + inbox)

**Menjalankan:** `mailpit`. **Toggle:** `LDS_ENABLE_MAIL`. **Mati secara default.**

- **Image:** `axllent/mailpit:${MAILPIT_VERSION}`.
- **Web UI:** `${MAIL_HOST}` (default `mail.test`) / `${MAIL_HOST_PORT}` (default `4513`).
- **SMTP:** host `${MAIL_SMTP_HOST_PORT}` (default `4514`) → container `1025`.
- **Storage:** persisten di `data/mailpit/` (`MP_DATA_FILE`).

## `penpot` — collaborative design tool

**Menjalankan:** `penpot-frontend`, `penpot-backend`, `penpot-exporter`. **Toggle:** `LDS_ENABLE_PENPOT`. **Mati secara default.**

- **UI:** `${PENPOT_HOST}` (default `penpot.test`) / `${PENPOT_HOST_PORT}` (default `4518`).
- **Dependensi:** memakai `postgres` dan `valkey` bersama (terikut profile `penpot`).
- **Default DB:** reuse `${PENPOT_POSTGRES_DB:-app}` dengan `${PENPOT_POSTGRES_USER:-app}`.
- **Assets:** persisten di host `data/penpot/assets`.

## `openwa` — gateway API WhatsApp

**Menjalankan:** `openwa`. **Toggle:** `LDS_ENABLE_OPENWA`. **Mati secara default.**

Gateway API WhatsApp self-hosted (fork `rmyndharis/OpenWA`) — backend NestJS +
dashboard React, manajemen multi-sesi, webhook, engine WhatsApp yang bisa
diganti (whatsapp-web.js / Baileys).

- **Image:** `ghcr.io/rmyndharis/openwa:${OPENWA_VERSION}` (default `latest`).
- **UI/API:** `${OPENWA_HOST}` (default `openwa.test`) / host port
  `${OPENWA_HOST_PORT}` (default `4507`) → container `2785`.
- **Dependensi:** memakai `postgres` bersama (DB khusus `lds_openwa`, dibuat
  otomatis via `POSTGRES_INIT_SPECS`) dan `redis` (opsional,
  `OPENWA_REDIS_ENABLED` nonaktif secara default).
- **Master key:** `${OPENWA_MASTER_KEY}` (default dev di `.env` — ganti sebelum
  mengekspos stack).
- **Volume:** `openwa-data` (`/app/data` — sesi, media).

## `rustfs` — berbagi file (kompatibel S3)

**Menjalankan:** `rustfs`. **Toggle:** `LDS_ENABLE_RUSTFS`. **Mati secara default.**

Server object storage self-hosted kompatibel S3 dengan console web — alternatif
berbagi file self-hosted open-source.

- **Image:** `rustfs/rustfs:${RUSTFS_VERSION}` (default `latest`).
- **API:** host port `${RUSTFS_API_PORT}` (default `4508`) → container `9000`
  (API S3).
- **Console:** `${RUSTFS_HOST}` (default `rustfs.test`) / host port
  `${RUSTFS_CONSOLE_PORT}` (default `4509`) → container `9001`.
- **Kredensial:** `${RUSTFS_ACCESS_KEY}` / `${RUSTFS_SECRET_KEY}` (default dev di
  `.env`); bucket default `${RUSTFS_BUCKET}` (default `lds-data`) dibuat saat
  boot pertama.
- **Volume:** `rustfs-data`.

## `headlessx` — automasi browser anti-deteksi / scraping

**Menjalankan:** `headlessx-api`, `headlessx-worker`, `headlessx-web`, `headlessx-html-to-md`,
`headlessx-yt-engine`. **Toggle:** `LDS_ENABLE_HEADLESSX`. **Mati secara default.**
Dibangun dari source — tidak ada image yang dipublikasikan.

- **Apa itu:** platform scraping self-hosted — dashboard Next.js, Express API +
  worker antrean, endpoint MCP jarak jauh (`/mcp`), ditenagai runtime browser
  Firefox yang di-patch (Camoufox).
- **Source:** checkout git lokal dari `https://github.com/saifyxpro/HeadlessX` di
  `${HEADLESSX_REPO_PATH}` (default `data/headlessx`). `lds up headlessx` (atau
  `lds headlessx init`) meng-clone-nya saat pertama kali dan fast-forward
  setelahnya; `lds headlessx update` menyegarkan secara manual.
- **Dependensi:** memakai `postgres` bersama (DB khusus `lds_headlessx`,
  dibuat otomatis via `POSTGRES_INIT_SPECS`) dan `redis` (DB logis
  `${HEADLESSX_REDIS_DB}`, default `4`) — keduanya otomatis start oleh profile
  `headlessx`.
- **UI/API:** web di `${HEADLESSX_HOST}` (default `headlessx.test`) / host port
  `${HEADLESSX_WEB_HOST_PORT}` (default `4515`); API + MCP di
  `${HEADLESSX_API_HOST}` (default `headlessx-api.test`) / host port
  `${HEADLESSX_API_HOST_PORT}` (default `4516`). Dashboard mem-proxy `/api/*`
  ke API secara internal, jadi browser hanya bicara ke `headlessx.test`.
- **Kunci:** `HEADLESSX_DASHBOARD_INTERNAL_API_KEY` +
  `HEADLESSX_CREDENTIAL_ENCRYPTION_KEY` (default dev di `.env` — ganti sebelum
  mengekspos stack).
- **Run pertama Google AI Search:** buka playground Google AI Search, klik
  **Build Cookies**, browsing sekali, lalu **Stop Browser** — sesi tersimpan di
  volume `headlessx-browser-profile` dan dipakai ulang.
- **Berat:** `lds up headlessx` pertama membangun empat image (install pnpm/nx +
  unduh bundle browser) — bangun pertama lama dan beberapa GB RAM saat berjalan.

## `playwright` — pengujian End-To-End

**Menjalankan:** `playwright` (runner) + `playwright-report` (viewer). **Toggle:**
`LDS_ENABLE_PLAYWRIGHT`. **Mati secara default.**

- **Runner:** image resmi `mcr.microsoft.com/playwright:${PLAYWRIGHT_VERSION}`
  (Node + Chromium/Firefox/WebKit terpasang). Container berjalan lama dan
  bergabung ke **DNS in-network** (seperti ZAP) sehingga browser-nya me-resolve
  `*.test` melalui proxy dan dapat menguji layanan `http://<app>.test` persis
  seperti browser host.
- **Proyek:** proyek tes berada di `data/playwright/projects/<nama>`
  (scaffold dengan `lds playwright init <nama> [url]`, yang meng-pin
  `@playwright/test` ke versi Playwright image).
- **Jalankan:** `lds playwright run <nama> [argumen playwright…]` mengeksekusi
  `npx playwright test` di container yang hangat (auto-`npm install` saat run
  pertama). Rekam tes dengan `lds playwright codegen <url>`, eksplorasi dengan
  `lds playwright shell`.
- **UI Mode:** `lds playwright ui <nama>` menyajikan UI interaktif Playwright
  (watch mode, time-travel debugging, jalankan tes individual) di host port
  `${PLAYWRIGHT_UI_HOST_PORT}` (default `4527`) — buka di browser Anda. Panel
  UI adalah web app di browser; tesnya sendiri tetap dieksekusi di browser
  headless container.
- **Laporan:** setiap run menulis laporan HTML ke
  `data/playwright/reports/<nama>/`, disajikan viewer di
  `${PLAYWRIGHT_REPORT_HOST}` (default `playwright.test`) / host port
  `${PLAYWRIGHT_REPORT_HOST_PORT}` (default `4526`).
- **Berat:** image runner memuat ketiga browser (~1.5 GB) — pull pertama
  `lds up playwright` / `lds playwright run` agak lama.

## `all` — semuanya

**Toggle:** tidak ada — berikan eksplisit dengan `lds up all`, atau ini menjadi
fallback otomatis saat semua toggle `LDS_ENABLE_*` bernilai `false`. Setiap
layanan di atas termasuk profile `all`, jadi ini menjalankan seluruh stack
sekaligus. Berat — pakai hanya saat Anda benar-benar menginginkan semuanya (atau
untuk smoke test cepat).

---

## TLS / sertifikat — default HTTP, HTTPS opt-in

**Secara default tidak ada sertifikat** — `proxy` edge dan nginx `php` hanya
mendengarkan di port `80`, jadi setiap `<nama>.test`, `cache.test`, `db.test`,
`mqtt.test`, dst. dilayani melalui **`http://`** biasa. Ini default yang tepat
untuk dev lokal: tanpa setup sertifikat, tanpa prompt trust browser, dan tool
seperti Debezium/Connect bicara ke broker dan DB langsung lewat jaringan internal.

Saat Anda memang butuh HTTPS lokal (menguji cookie `Secure`, HSTS, service
worker, atau SDK yang menolak non-TLS), aktifkan **overlay HTTPS** — satu
sertifikat wildcard untuk `*.test` yang diterminasi di proxy pada port `443`:

1. **Buat cert dev** (sekali): `lds certs`. Lebih memilih
   [`mkcert`](https://github.com/FiloSottile/mkcert) (memasang CA lokal terpercaya
   → tanpa peringatan browser); bila mkcert tidak ada, jatuh ke cert self-signed
   `openssl` (berfungsi, tapi browser memperingatkan sampai Anda mempercayainya).
   Cert ada di `configs/proxy/certs/test.{crt,key}` (di-gitignore — berisi
   private key) dengan SAN mencakup `*.test`, `test`, dan `localhost`. Dinamai
   sesuai TLD agar nginx-proxy otomatis mencocokkan setiap vhost `<nama>.test`;
   container php menyetel `CERT_NAME=test` agar `localhost` dan catch-all proyek
   PHP juga memakainya.
2. **Aktifkan toggle** di `.env`: `LDS_ENABLE_HTTPS=true`.
3. **Restart:** `lds up`. Saat HTTPS aktif *dan* ada profile `proxy`/`php` di
   run-set, `lds up` melapisi `docker-compose.https.yml` di atas file dasar —
   menambah listener `443` (`${WEB_HTTPS_PORT}`), mount certs, dan `HTTPS_METHOD`
   — serta otomatis membuat cert bila belum ada. Kini `https://<nama>.test`,
   `https://cache.test`, dst. semua jalan.

`HTTPS_METHOD=noredirect` (default) menjaga **http dan https** tetap jalan; set
`HTTPS_METHOD=redirect` di `.env` untuk memaksa http → https. Ini overlay sejati:
dengan `LDS_ENABLE_HTTPS=false`, stack dasar identik dengan setup hanya-HTTP, jadi
tidak ada yang berubah sampai Anda memilih ikut.

### Mengatasi `ERR_CERT_AUTHORITY_INVALID`

- **Sudah regenerasi cert tapi browser tetap menolak?** nginx hanya membaca ulang
  berkas cert saat reload — mengubah berkas yang di-bind-mount **tidak** me-restart
  proxy, jadi ia tetap menyajikan cert *lama*. `lds certs` kini otomatis me-reload
  `lds-proxy`; jika Anda menukar berkasnya manual, jalankan `lds certs --force`
  (atau `docker exec lds-proxy nginx -s reload`). Cek apa yang benar-benar
  disajikan:
  `echo | openssl s_client -connect 127.0.0.1:443 -servername app.test | openssl x509 -noout -issuer`
  — issuer seharusnya `mkcert development CA`, bukan `O=local-dev-stack`
  (yang terakhir adalah fallback self-signed yang tidak terpercaya).
- **Memakai fallback self-signed** (mkcert belum terpasang saat cert dibuat) →
  tidak ada CA terpercaya, jadi semua browser memperingatkan. Pasang
  [`mkcert`](https://github.com/FiloSottile/mkcert), lalu `lds certs --force`.
- **Cert mkcert tapi tetap tidak terpercaya?** CA lokal harus ada di trust store —
  `mkcert -install` melakukannya (jalankan ulang bila perlu). Lalu **restart penuh
  browser** (Chrome/Edge meng-cache error cert per sesi; hard refresh tidak cukup).
  **Firefox** punya trust store *sendiri* — mkcert hanya menambah CA ke sana bila
  tool NSS tersedia, jika tidak percayai CA-nya di Firefox secara manual.

Lihat [12 · Port](12-ports.md) untuk peta port host lengkap, dan
[09 · Kafka + Debezium](09-kafka-debezium.md) untuk stack Kafka secara mendalam.
