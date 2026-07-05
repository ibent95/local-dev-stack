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
  `php`, `mysql`, `dbgate` aktif; selain itu mati. Jika semua toggle
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
<td>`dbgate`</td>
<td>`LDS_ENABLE_DBGATE`</td>
<td>✅</td>
<td>`dbgate`</td>
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
<td>`drawdb` — perancang skema DB (buka di `localhost:4423`)</td>
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
<td>`all`</td>
<td>—</td>
<td>—</td>
<td>semua layanan di atas</td>
</tr>
</tbody>
</table>

> **Aplikasi kustom** (`analytics`, `tasks`, `wiki`) dan **tool data** (`drawdb`, `hop`, `superset`, `semgrep`, `vaultwarden`) punya halaman sendiri —
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
  - Bootstrap broker: host `${KAFKA_HOST_PORT}` (default `4410`) → `29092`
    (EXTERNAL); client di dalam jaringan memakai `kafka-broker:9092` (INTERNAL).
- **`schema-registry`** — **Apicurio Registry** (Apache 2.0, in-memory) di host
  `${SCHEMA_REGISTRY_HOST_PORT}` (default `4411`). API kompatibel Confluent di
  `/apis/ccompat/v7`. Hanya dev: skema reset saat restart (didaftarkan ulang
  otomatis).
- **`connect-debezium`** — Kafka Connect pada image **Debezium** (connector
  source CDC MySQL + Postgres sudah terpaket). REST di `${CONNECT_HOST_PORT}`
  (default `4413`). JSON connector ada di `configs/kafka/connect/`.
- **`connect-generic`** — Kafka Connect pada image **apache/kafka vanilla**
  (runtime sama, **tanpa** connector bawaan). Taruh JAR plugin di
  `configs/kafka/connect-generic/plugins/`. REST di `${CONNECT_GENERIC_HOST_PORT}`
  (default `4412`). Memakai group + topik state sendiri agar tidak bentrok dengan
  worker Debezium.
- **`kafka-ui`** — Kafka UI kafbat di host `${KAFKA_UI_HOST_PORT}` (default
  `4420`), sudah terhubung ke broker, schema registry, dan kedua worker Connect.
- **Topik:** disediakan dari `${KAFKA_TOPICS}` oleh `scripts/run/kafka-topics.*`
  (otomatis dijalankan `lds up` untuk profile kafka, atau manual via
  `lds kafka-topics`).
- **Volume:** `kafka-controller-data`, `kafka-broker-data`.

## UI admin — `phpcacheadmin` dan `dbgate`

Kedua UI admin web kini punya **profile masing-masing** sehingga dapat diaktifkan
secara independen (tidak ada lagi umbrella `tools`). Keduanya dijangkau via proxy
(`*.test`) **dan** port host langsung, dan hanya menampilkan data bila profile
data yang sesuai juga jalan.

> Untuk URL `.test` Anda juga perlu `proxy` (atau `php`) jalan; untuk data nyata,
> jalankan profile `mysql` / `postgres` / `redis` / `memcached` yang sesuai.

### `phpcacheadmin` — browser Redis + Memcached

**Menjalankan:** `phpcacheadmin`. **Toggle:** `LDS_ENABLE_PHPCACHEADMIN`. **Mati
secara default** (aktifkan saat Anda menjalankan `redis`/`memcached`).

- Browser Redis + Memcached + OPcache/APCu. `${CACHE_ADMIN_HOST}` (default
  `cache.test`) / host `${CACHE_ADMIN_HOST_PORT}` (default `4421`).
- Sudah diarahkan ke layanan `redis` dan `memcached` — jalankan salah satu (atau
  keduanya) untuk melihat data. Tanpa volume (UI stateless).

### `dbgate` — client DB web

**Menjalankan:** `dbgate`. **Toggle:** `LDS_ENABLE_DBGATE`. **Aktif secara
default.**

- Client DB web. `${DB_ADMIN_HOST}` (default `db.test`) / host
  `${DB_ADMIN_HOST_PORT}` (default `4422`).
- Berjalan terbuka penuh (tambah/edit/hapus koneksi di UI); MySQL + Postgres stack
  otomatis terdaftar via `scripts/run/dbgate-seed.*` (otomatis dijalankan `lds up`
  untuk profile `dbgate`/`all`). Koneksi buatan UI tersimpan di direktori
  bind-mount `data/dbgate/`.

## Broker realtime / pub-sub — `soketi`, `centrifugo`, `mqtt`

Ketiganya **mati secara default**, **stateless** (tanpa volume data → tanpa
penumpukan disk), dan **dibatasi mem/cpu**. Mereka berbicara protokol klien yang
**berbeda** dan **tidak** dapat saling tukar — pilih yang protokol kliennya cocok
dengan aplikasi Anda. Satu broker melayani channel/topik tak terbatas; Anda tidak
perlu instance kedua per channel.

### `soketi` — protokol Pusher

**Toggle:** `LDS_ENABLE_SOKETI`. Headless (tanpa UI).

- **Image:** `quay.io/soketi/soketi:${SOKETI_VERSION}`. Port host
  `${SOKETI_HOST_PORT}` (default `4430`) → `6001`; juga `${SOKETI_HOST}` (default
  `ws.test`) via proxy.
- Drop-in untuk **broadcasting Laravel** (`BROADCAST_DRIVER=pusher`/reverb) +
  **Laravel Echo** / `pusher-js`. Kredensial app: `${SOKETI_APP_ID}` /
  `${SOKETI_APP_KEY}` / `${SOKETI_APP_SECRET}` (default dev — ganti untuk yang
  dipakai bersama).
- Batas: `${SOKETI_MEM_LIMIT}` (default `256m`), `${SOKETI_CPUS}` (default `0.50`).

### `centrifugo` — channel WebSocket mentah + UI admin

**Toggle:** `LDS_ENABLE_CENTRIFUGO`.

- **Image:** `centrifugo/centrifugo:${CENTRIFUGO_VERSION}`. Port host
  `${CENTRIFUGO_HOST_PORT}` (default `4431`) → `8000`; UI admin di
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
  `${MQTT_HOST_PORT}` (default `4432`) → `1883` (MQTT native),
  `${MQTT_WS_HOST_PORT}` (default `4433`) → `9001` (MQTT-over-WebSocket, path `/`).
- **Image web client:** `emqx/mqttx-web:${MQTTX_VERSION}` di
  `${MQTT_HOST}` (default `mqtt.test`) / `${MQTTX_HOST_PORT}` (default `4434`).
- Klien tetap memakai **library MQTT** (MQTT.js / Paho di browser, MQTT native
  untuk backend). `mqttx` adalah UI client (publish/subscribe), bukan dashboard admin broker.
- Batas: `${MOSQUITTO_MEM_LIMIT}` (default `128m`), `${MQTTX_MEM_LIMIT}` (default `128m`).

## `vaultwarden` — password manager

**Menjalankan:** `vaultwarden`. **Toggle:** `LDS_ENABLE_VAULTWARDEN`. **Mati secara default.**

- **Image:** `vaultwarden/server:${VAULTWARDEN_VERSION}`.
- **UI/API:** `${VAULTWARDEN_HOST}` (default `vaultwarden.test`) dan host port
  `${VAULTWARDEN_HOST_PORT}` (default `4429`).
- **Storage:** volume persisten berbasis sqlite (`vaultwarden-data`).
- **Default:** signup nonaktif (`VAULTWARDEN_SIGNUPS_ALLOWED=false`);
  panel admin dilindungi `VAULTWARDEN_ADMIN_TOKEN`.

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
