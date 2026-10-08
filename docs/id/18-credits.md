# 18 · Kredit & Perangkat Lunak Pihak Ketiga

Local Dev Stack adalah penyusun, bukan penemu: hampir semua yang dijalankannya
adalah karya orang lain. Bab ini mencantumkan setiap pustaka, aplikasi, image
container, dan alat sistem yang digunakan stack - apa fungsinya, versi yang kita
kunci, dan lisensinya.

Tiga catatan sebelum tabel:

- **Versi** = nilai bawaan di `.env.example` / `docker-compose.yml`
  (`${VAR:-default}`). Ubah di `.env` lalu buat ulang servicenya. Tag tanpa
  variabel berarti ditulis tetap (hard-coded) di berkas compose atau Dockerfile.
- **Lisensi** = lisensi proyek atau image sebagaimana diterbitkan upstream.
  Beberapa entri bersifat proprietary (SQL Server, Oracle) - itu gratis untuk
  pengembangan lokal di bawah ketentuan penerbitnya sendiri, tidak lebih.
- Hampir tidak ada kode pihak ketiga di repositori ini sendiri. Berkas yang kita
  bundel (tabel terakhir) tetap menyertakan teks lisensinya. Saat kamu menambah
  service ke `docker-compose.yml`, beri dia baris di sini.

## Image dasar & runtime bahasa

<table>
<thead><tr><th>Proyek</th><th>Fungsinya di LDS</th><th>Versi (env)</th><th>Lisensi</th></tr></thead>
<tbody>
<tr><td><a href="https://dhi.io/">Docker Hardened Images (DHI)</a></td><td>Image dasar minimal yang dikeraskan di bawah <code>${DHI_REGISTRY}</code> - setiap image service dan setiap base <code>lds/*</code> dibuat <code>FROM</code> mereka</td><td><code>DHI_REGISTRY</code> = <code>dhi.io</code></td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td>Alpine Linux</td><td>Distro di balik base bahasa (image <code>-alpine3.24-dev</code> DHI untuk <code>golang</code>/<code>node</code>/<code>python</code>/<code>rust</code>/<code>eclipse-temurin</code>) dan image <code>dns</code></td><td>3.24</td><td>Campuran (per paket)</td></tr>
<tr><td>Debian</td><td>Distro di balik <code>lds/php</code>, <code>lds/duckdev</code>, dan image scanner CRG (<code>python:3.12-slim</code>)</td><td>13 (trixie)</td><td><a href="https://www.debian.org/legal/">Campuran (per paket)</a></td></tr>
<tr><td><code>lds/php</code></td><td>Satu-satunya base PHP, di atas Debian 13: php-fpm + nginx + composer + supervisor + supercronic (dibuat dari repositori ini)</td><td><code>PHP_VERSION</code> = 8.4</td><td><a href="https://www.php.net/license/3_01.txt">PHP-3.01</a> (runtime-nya)</td></tr>
<tr><td><a href="https://getcomposer.org/">Composer</a></td><td>Disalin ke <code>lds/php</code> dari image resmi agar template PHP bisa mengelola dependensi</td><td><code>composer:2</code> (tag mengambang)</td><td><a href="https://opensource.org/license/mit">MIT</a></td></tr>
<tr><td><code>lds/go-dev</code></td><td>Toolchain Go + <a href="https://github.com/air-verse/air">air</a> (live-reload) untuk template <code>go</code></td><td><code>GO_VERSION</code> = 1.26</td><td><a href="https://go.dev/LICENSE">BSD-3-Clause</a> (Go); air <a href="https://opensource.org/license/mit">MIT</a></td></tr>
<tr><td><code>lds/rust-dev</code></td><td>Toolchain Rust + cargo-watch, rustup, dan CLI Tauri untuk template <code>rust</code>/<code>tauri</code></td><td><code>RUST_VERSION</code> = 1.96</td><td><a href="https://opensource.org/license/mit">MIT</a> <b>OR</b> <a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><code>lds/node-dev</code></td><td>Toolchain Node.js untuk template <code>node</code>/<code>express</code>/SPA serta API analytics, tasks, dan wiki</td><td><code>NODE_VERSION</code> = 26.3</td><td><a href="https://github.com/nodejs/node/blob/main/LICENSE">MIT (Node.js)</a></td></tr>
<tr><td><code>lds/python-dev</code></td><td>Toolchain Python + watchfiles untuk template <code>python</code>/<code>flask</code>/<code>fastapi</code>/<code>django</code></td><td><code>PYTHON_VERSION</code> = 3.14</td><td><a href="https://docs.python.org/3/license.html">PSF-2.0</a>; watchfiles <a href="https://opensource.org/license/mit">MIT</a></td></tr>
<tr><td><code>lds/java-dev</code></td><td>JDK Eclipse Temurin + Apache Maven untuk template Java, Spring, Micronaut, Quarkus, dan Vaadin</td><td><code>JAVA_VERSION</code> = 25</td><td><a href="https://openjdk.org/legal/gplv2+ce.html">GPL-2.0 WITH Classpath-exception</a>; Maven <a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><code>lds/javafx-dev</code></td><td>OpenJFX di atas <code>lds/java-dev</code> untuk template desktop JavaFX</td><td>dari <code>JAVA_VERSION</code></td><td><a href="https://openjdk.org/legal/gplv2+ce.html">GPL-2.0 WITH Classpath-exception</a></td></tr>
<tr><td><code>lds/nativephp-dev</code></td><td>Toolchain NativePHP di atas <code>lds/php</code> untuk aplikasi desktop/mobile native berbasis PHP</td><td>dari <code>PHP_VERSION</code></td><td><a href="https://github.com/NativePHP/desktop/blob/main/LICENSE.md">MIT</a></td></tr>
<tr><td><code>lds/tauri-dev</code> / <code>tauri-win-dev</code></td><td>Base Rust ke desktop native untuk template Tauri</td><td>dari <code>RUST_VERSION</code></td><td><a href="https://github.com/tauri-apps/tauri/blob/dev/LICENSE_APACHE">Apache-2.0</a> (runtime); MIT/Apache-2.0 (CLI)</td></tr>
<tr><td><code>lds/duckdev</code></td><td>Base untuk image pembantu DuckDB yang membundel CLI DuckDB</td><td><code>DUCKDB_VERSION</code> = 1.2.0</td><td><a href="https://github.com/duckdb/duckdb/blob/main/LICENSE">MIT</a></td></tr>
</tbody>
</table>

## Edge web, DNS & TLS

<table>
<thead><tr><th>Proyek</th><th>Fungsinya di LDS</th><th>Versi (env)</th><th>Lisensi</th></tr></thead>
<tbody>
<tr><td><a href="https://github.com/nginx-proxy/nginx-proxy">nginx-proxy</a></td><td>Pintu depan: satu nginx yang merutekan setiap <code>&lt;folder&gt;.test</code> dan hostname alat ke container-nya lewat <code>VIRTUAL_HOST</code></td><td>1.6</td><td><a href="https://opensource.org/license/mit">MIT</a></td></tr>
<tr><td>nginx (<code>lds/nginx</code>)</td><td>Runtime nginx terkunci yang dipakai ulang oleh container viewer/UI stack ini (viewer laporan Semgrep, Trivy, dan CRG, serta UI tasks/wiki). nginx mass-virtual-host yang menyajikan setiap docroot <code>.test</code> tertanam di <code>lds/php</code></td><td><code>NGINX_VERSION</code> = 1.27</td><td><a href="https://nginx.org/en/LICENSE.html">BSD-2-Clause</a></td></tr>
<tr><td>dnsmasq</td><td>Menjawab <code>*.test</code> dengan 127.0.0.1 untuk host, dan dengan IP proxy untuk ZAP di dalam jaringan</td><td>dari image <code>dns</code></td><td><a href="https://www.gnu.org/licenses/old-licenses/gpl-2.0.html">GPL-2.0</a></td></tr>
</tbody>
</table>

## Basis data

<table>
<thead><tr><th>Proyek</th><th>Fungsinya di LDS</th><th>Versi (env)</th><th>Lisensi</th></tr></thead>
<tbody>
<tr><td>MySQL</td><td>Basis data SQL bersama, siap CDC (binlog + GTID) untuk Debezium</td><td><code>MYSQL_VERSION</code> = 8.4-debian13</td><td><a href="https://www.mysql.com/about/legal/licensing/">GPL-2.0 + FOSS exception</a></td></tr>
<tr><td>MariaDB</td><td>Basis data SQL alternatif yang drop-in (<code>LDS_ENABLE_MARIADB</code>)</td><td><code>MARIADB_VERSION</code> = 11.8-debian13</td><td><a href="https://mariadb.com/about/license/">GPL-2.0</a></td></tr>
<tr><td>SQL Server (Developer)</td><td>Edisi penuh yang gratis untuk pengembangan dan pengujian</td><td><code>MSSQL_VERSION</code> = 2025-latest</td><td><a href="https://www.microsoft.com/licensing/terms/product/formentities/SQLServer">EULA proprietary</a> (gratis untuk dev/test)</td></tr>
<tr><td>Oracle Database Free</td><td>Memakai image mirror <a href="https://github.com/gvenzl/oci-oracle-free">gvenzl/oracle-free</a>, tanpa perlu akun Oracle</td><td><code>ORACLE_VERSION</code> = 23.26.2-slim</td><td>image <a href="https://github.com/gvenzl/oci-oracle-free/blob/main/LICENSE">Apache-2.0</a>; databasenya <a href="https://www.oracle.com/downloads/licenses/technology-license.html">Oracle Free Use Terms</a></td></tr>
<tr><td>PostgreSQL</td><td>Basis data SQL bersama, siap CDC (WAL logis); juga menampung ERPNext</td><td><code>POSTGRES_VERSION</code> = 18.4-alpine3.24</td><td><a href="https://www.postgresql.org/about/licence/">Lisensi PostgreSQL</a></td></tr>
<tr><td>MongoDB</td><td>Basis data dokumen pada replica set satu node (<code>rs0</code>) dengan autentikasi, siap CDC</td><td><code>MONGO_VERSION</code> = 8.3-debian13-dev</td><td><a href="https://www.mongodb.com/licensing/server-side-public-license">SSPL-1.0</a></td></tr>
<tr><td>Redis</td><td>Cache, antrean, dan broker untuk job serta framework (Laravel, ERPNext, Superset)</td><td><code>REDIS_VERSION</code> = 8.8-alpine3.24</td><td><a href="https://redis.io/legal/open-source-notice/">RSALv2 / SSPL (pilihanmu)</a></td></tr>
<tr><td>Valkey</td><td>Alternatif drop-in yang kompatibel dengan Redis (<code>LDS_ENABLE_VALKEY</code>)</td><td><code>VALKEY_VERSION</code> = 8.1-alpine</td><td><a href="https://opensource.org/license/bsd-3-clause">BSD-3-Clause</a></td></tr>
<tr><td>Memcached</td><td>Cache memori, juga bisa ditelusuri lewat phpCacheAdmin</td><td><code>MEMCACHED_VERSION</code> = 1.6-debian13</td><td><a href="https://opensource.org/license/bsd-3-clause">BSD-3-Clause</a></td></tr>
<tr><td><a href="https://www.rabbitmq.com/">RabbitMQ</a></td><td>Broker pesan AMQP bersama dengan UI manajemen (<code>localhost:4411</code>); antrean tugas Plane berjalan di atasnya</td><td><code>RABBITMQ_VERSION</code> = 3.13.6</td><td><a href="https://github.com/rabbitmq/rabbitmq-server/blob/main/LICENSE">MPL-2.0</a></td></tr>
<tr><td><a href="https://github.com/t8y2/dbx">DBX</a></td><td>Klien web untuk 100+ basis data, sudah terisi database milik stack sendiri (<code>db.test</code>)</td><td><code>DBX_VERSION</code> = 0.6.31</td><td><a href="https://github.com/t8y2/dbx/blob/main/LICENSE">Apache-2.0</a></td></tr>
<tr><td><a href="https://github.com/RobiNN1/phpCacheAdmin">phpCacheAdmin</a></td><td>GUI untuk Redis, Valkey, Memcached, OPcache, dan APCu (<code>cache.test</code>)</td><td><code>PHPCACHEADMIN_VERSION</code> = 2.5.2</td><td><a href="https://github.com/RobiNN1/phpCacheAdmin/blob/master/LICENSE">MIT</a></td></tr>
</tbody>
</table>

## Streaming (Kafka & realtime)

<table>
<thead><tr><th>Proyek</th><th>Fungsinya di LDS</th><th>Versi (env)</th><th>Lisensi</th></tr></thead>
<tbody>
<tr><td>Apache Kafka</td><td>Broker KRaft + controller khusus yang menjalankan seluruh beban CDC dan messaging</td><td><code>KAFKA_VERSION</code> = 4.3-debian13</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td>Kafka Connect</td><td>Runtime connector yang ikut dengan Kafka, dipakai untuk CDC dan sink generik</td><td>dengan <code>KAFKA_VERSION</code></td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://debezium.io/">Debezium</a></td><td>Connector CDC (MySQL, Postgres, MongoDB ke Kafka) di worker khusus, REST di <code>:4423</code></td><td><code>DEBEZIUM_VERSION</code> = 3.0</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://apicurio.io/">Apicurio Registry</a></td><td>Schema registry in-memory; nilai Avro lewat converter Apicurio Connect</td><td><code>APICURIO_VERSION</code> = 2.6.13.Final</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://kafbat.io/">Kafbat kafka-ui</a></td><td>UI browser untuk topik, connector, dan skema (<code>kafka.test</code>, ccompat di <code>/apis/ccompat/v7</code>)</td><td><code>KAFKA_UI_VERSION</code> = v1.5.0</td><td><a href="https://github.com/kafbat/kafka-ui/blob/main/LICENSE">Apache-2.0</a></td></tr>
<tr><td>Worker Connect generik</td><td>Image DHI Kafka yang dijalankan sebagai worker Connect kedua; plugin ditambahkan dengan <code>lds connect-plugin</code></td><td>dengan <code>KAFKA_VERSION</code></td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://github.com/eclipse/mosquitto">Eclipse Mosquitto</a></td><td>Broker MQTT dengan listener native (<code>:4442</code>) dan WebSocket (<code>:4443</code>)</td><td><code>MOSQUITTO_VERSION</code> = 2.0.22</td><td><a href="https://www.eclipse.org/legal/epl-2.0/">EPL-2.0</a> / <a href="https://spdx.org/licenses/EDL-1.0.html">EDL-1.0</a></td></tr>
<tr><td><a href="https://mqttx.app/">MQTTX Web</a></td><td>Klien browser MQTT untuk mengoprek broker (<code>mqtt.test</code>)</td><td><code>MQTTX_VERSION</code> = v1.13.0</td><td><a href="https://github.com/emqx/MQTTX/blob/main/LICENSE">Apache-2.0</a></td></tr>
<tr><td><a href="https://github.com/soketi/soketi">Soketi</a></td><td>Server WebSocket protokol Pusher untuk Laravel Reverb/Echo dan klien pusher-js</td><td><code>SOKETI_VERSION</code> = 1.6-16-alpine</td><td><a href="https://github.com/soketi/soketi/blob/1.x/LICENSE">AGPL-3.0</a></td></tr>
<tr><td><a href="https://centrifugal.github.io/centrifugo/">Centrifugo</a></td><td>Kanal WebSocket mentah dengan UI admin (<code>centrifugo.test</code>), berjalan dalam mode dev insecure</td><td><code>CENTRIFUGO_VERSION</code> = v5</td><td><a href="https://github.com/centrifugal/centrifugo/blob/master/LICENSE">Apache-2.0</a></td></tr>
</tbody>
</table>

## Data, ETL & BI

<table>
<thead><tr><th>Proyek</th><th>Fungsinya di LDS</th><th>Versi (env)</th><th>Lisensi</th></tr></thead>
<tbody>
<tr><td><a href="https://hop.apache.org/">Apache Hop</a></td><td>Perancang dan server ETL visual (<code>hop.test</code>), proyek otomatis terdaftar dari <code>HOP_PROJECTS_PATH</code></td><td><code>HOP_VERSION</code> = 2.18.1</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://superset.apache.org/">Apache Superset</a></td><td>Dashboard BI (<code>superset.test</code>), metadata di Postgres bersama</td><td><code>SUPERSET_VERSION</code> = 6.1-debian13</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://www.metabase.com/">Metabase</a></td><td>Dashboard BI self-hosted (<code>metabase.test</code>), DB aplikasi di Postgres bersama</td><td><code>METABASE_VERSION</code> = v0.63.19.x</td><td><a href="https://github.com/metabase/metabase/blob/master/LICENSE.txt">AGPL-3.0</a></td></tr>
<tr><td><a href="https://hoppscotch.com/">Hoppscotch</a></td><td>API client self-hosted (<code>hoppscotch.test</code>), DB aplikasi Postgres di server bersama</td><td><code>HOPPSCOTCH_VERSION</code> = 2026.9.0</td><td><a href="https://github.com/hoppscotch/hoppscotch/blob/develop/LICENSE">MIT</a></td></tr>
<tr><td><a href="https://plane.so/">Plane</a></td><td>Manajemen proyek (<code>plane.test</code>), stack CE vendor (Postgres/Redis/RustFS/RabbitMQ bersama)</td><td><code>APP_RELEASE</code> = stable</td><td><a href="https://github.com/makeplane/plane/blob/preview/LICENSE.txt">AGPL-3.0</a></td></tr>
<tr><td><a href="https://github.com/drawdb-io/drawdb">DrawDB</a></td><td>Perancang skema/ER di browser, dibuka di <code>localhost:4502</code> (butuh konteks aman)</td><td><code>DRAWDB_VERSION</code> = v1.7.0</td><td><a href="https://github.com/drawdb-io/drawdb/blob/main/LICENSE">AGPL-3.0</a></td></tr>
<tr><td><a href="https://duckdb.org/">DuckDB</a></td><td>Engine OLAP tertanam; CLI-nya dibundel dan dipakai skrip bantu lokal</td><td><code>DUCKDB_VERSION</code> = 1.2.0</td><td><a href="https://github.com/duckdb/duckdb/blob/main/LICENSE">MIT</a></td></tr>
<tr><td><a href="https://trino.io/">Trino</a></td><td>Engine SQL terfederasi (<code>trino.test</code>) untuk menanyakan beberapa basis data sekaligus</td><td><code>TRINO_VERSION</code> = latest</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://hive.apache.org/">Apache Hive</a></td><td>Hive metastore dan engine SQL, dihubungkan ke Trino serta Postgres bersama</td><td>hive:4.0.0 (hard-coded)</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td>pandas + PyArrow</td><td>Dipasang oleh <code>scripts/run/seed-data.sh</code> untuk membuat dataset contoh</td><td><code>pip</code> di host (tanpa kunci)</td><td><a href="https://opensource.org/license/bsd-3-clause">BSD-3-Clause</a> + <a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td>Driver JDBC</td><td>Enam driver dipasang single-file ke Hop dan Hive metastore, diunduh tiap developer (di-git-ignore)</td><td>dikunci per jar</td><td>Campuran - MySQL <a href="https://www.gnu.org/licenses/old-licenses/gpl-2.0.html">GPL-2.0</a>, MariaDB <a href="https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html">LGPL-2.1</a>, Oracle <a href="https://www.oracle.com/downloads/licenses/technology-license.html">Free Use Terms</a>, mssql <a href="https://opensource.org/license/mit">MIT</a>, PostgreSQL <a href="https://opensource.org/license/bsd-2-clause">BSD-2-Clause</a>, Trino <a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a> (lihat <code>assets/jdbc/README.md</code>)</td></tr>
</tbody>
</table>

## Aplikasi & platform

<table>
<thead><tr><th>Proyek</th><th>Fungsinya di LDS</th><th>Versi (env)</th><th>Lisensi</th></tr></thead>
<tbody>
<tr><td><a href="https://penpot.app/">Penpot</a></td><td>Alat desain dan prototipe open-source (container frontend, backend, dan exporter)</td><td><code>PENPOT_VERSION</code> = 2.17.0</td><td><a href="https://github.com/penpot/penpot/blob/develop/LICENSE">MPL-2.0</a></td></tr>
<tr><td><a href="https://erpnext.com/">ERPNext</a> (Frappe)</td><td>Suite ERP lengkap - sekitar delapan service plus dua job bootstrap, di Postgres/MariaDB dan Redis bersama</td><td><code>ERPNEXT_VERSION</code> = 16.31.1</td><td><a href="https://www.gnu.org/licenses/gpl-3.0.en.html">GPL-3.0</a></td></tr>
<tr><td><a href="https://github.com/dani-garcia/vaultwarden">Vaultwarden</a></td><td>Password manager kompatibel Bitwarden untuk secret lokal</td><td><code>VAULTWARDEN_VERSION</code> = 1.34.3</td><td><a href="https://github.com/dani-garcia/vaultwarden/blob/main/LICENSE.txt">AGPL-3.0</a></td></tr>
<tr><td><a href="https://github.com/CoreBunch/Instatic">Instatic</a></td><td>CMS visual / website builder self-hosted (<code>instatic.test</code>), SQLite dan unggahan di <code>data/instatic/</code></td><td><code>INSTATIC_VERSION</code> = 0.0.14</td><td><a href="https://github.com/CoreBunch/Instatic/blob/main/LICENSE">MIT</a></td></tr>
<tr><td><a href="https://github.com/axllent/mailpit">Mailpit</a></td><td>Penangkap SMTP dengan UI web, sehingga email dev tidak pernah keluar dari mesin</td><td><code>MAILPIT_VERSION</code> = v1.27</td><td><a href="https://github.com/axllent/mailpit/blob/master/LICENSE">MIT</a></td></tr>
<tr><td><a href="https://rustfs.com/">RustFS</a></td><td>Object storage kompatibel S3 untuk eksperimen bucket lokal</td><td><code>RUSTFS_VERSION</code> = latest</td><td><a href="https://github.com/rustfs/rustfs/blob/main/LICENSE">Apache-2.0</a></td></tr>
<tr><td><a href="https://openwa.dev/">open-wa</a></td><td>Gateway REST API WhatsApp self-hosted (image dari fork <code>rmyndharis/OpenWA</code> di GHCR)</td><td><code>OPENWA_VERSION</code> = latest</td><td><a href="https://firstdonoharm.dev/version/1/0/full.html">Hippocratic + Do Not Harm 1.0</a> (tersedia sumbernya, bukan OSI)</td></tr>
<tr><td>HeadlessX</td><td>Platform otomasi browser yang dibangun dari sumber ke <code>data/headlessx</code>, memakai Postgres dan Redis bersama</td><td>checkout sumber</td><td>lihat checkout upstream di <code>data/headlessx</code></td></tr>
<tr><td><a href="https://playwright.dev/">Playwright</a></td><td>Image runner E2E yang sudah berisi browser (<code>playwright.test</code>, UI mode di <code>:4527</code>)</td><td><code>PLAYWRIGHT_VERSION</code> = v1.62.1-noble</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a>; browser bawaan: Chromium <a href="https://opensource.org/license/bsd-3-clause">BSD-3-Clause</a>, Firefox <a href="https://www.mozilla.org/en-US/MPL/2.0/">MPL-2.0</a>, WebKit <a href="https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html">LGPL-2.1</a></td></tr>
</tbody>
</table>

## Utilitas & monitoring

<table>
<thead><tr><th>Proyek</th><th>Fungsinya di LDS</th><th>Versi (env)</th><th>Lisensi</th></tr></thead>
<tbody>
<tr><td><a href="https://github.com/snapotter-hq/SnapOtter">SnapOtter</a></td><td>Platform pemrosesan file mandiri - 300+ tool konversi/kompres/OCR/AI untuk gambar, video, audio, PDF dan dokumen, web UI + REST API (<code>snapotter.test</code>); berbagi postgres + redis stack</td><td><code>SNAPOTTER_VERSION</code> = 2.2.0</td><td><a href="https://www.gnu.org/licenses/agpl-3.0.en.html">AGPL-3.0</a></td></tr>
<tr><td><a href="https://github.com/karimz1/imgcompress">ImgCompress</a></td><td>Toolbox gambar - 70+ format input, kompres massal, gambar-ke-PDF, hapus latar AI lokal, container hardened tunggal (<code>imgcompress.test</code>)</td><td><code>IMGCOMPRESS_VERSION</code> = 0.9.0</td><td><a href="https://www.gnu.org/licenses/gpl-3.0.en.html">GPL-3.0</a></td></tr>
<tr><td><a href="https://github.com/jgraph/drawio">draw.io</a></td><td>Diagramming mandiri, ditautkan dalam mode offline (<code>drawio.test</code>)</td><td><code>DRAWIO_VERSION</code> = 31.6.1</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://github.com/lldap/lldap">LLDAP</a></td><td>Direktori LDAP ringan - backend autentikasi aplikasi Anda; web UI internal, kelola via DBX (<code>:4537</code>)</td><td><code>LLDAP_VERSION</code> = 2026-09-22</td><td><a href="https://www.gnu.org/licenses/gpl-3.0.en.html">GPL-3.0</a></td></tr>
<tr><td><a href="https://hub.docker.com/r/cleanstart/openldap">OpenLDAP</a></td><td>Direktori LDAP standar - tanpa web UI, kelola via DBX atau CLI LDAP (<code>:4540</code>), profile <code>openldap</code></td><td><code>OPENLDAP_VERSION</code> = 2.7.1-dev</td><td><a href="https://www.openldap.org/license/">OLDAP-2.8</a></td></tr>
<tr><td><a href="https://prometheus.io/">Prometheus</a></td><td>TSDB metrik pull-based, men-scrape dirinya sendiri + Grafana (<code>prometheus.test</code>), profile <code>monitoring</code></td><td><code>PROMETHEUS_VERSION</code> = v3.13.4</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://grafana.com/">Grafana</a></td><td>Dashboard dan alerting dengan datasource Prometheus di-provision otomatis (<code>grafana.test</code>), profile <code>monitoring</code></td><td><code>GRAFANA_VERSION</code> = 13.0.10</td><td><a href="https://www.gnu.org/licenses/agpl-3.0.en.html">AGPL-3.0</a></td></tr>
</tbody>
</table>

## Keamanan & kualitas kode

<table>
<thead><tr><th>Proyek</th><th>Fungsinya di LDS</th><th>Versi (env)</th><th>Lisensi</th></tr></thead>
<tbody>
<tr><td><a href="https://semgrep.dev/">Semgrep</a></td><td>Pindai SAST (<code>lds tools semgrep</code>) dengan viewer laporan SARIF di <code>semgrep.test</code></td><td><code>SEMGREP_VERSION</code> = 1.167.0</td><td><a href="https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html">LGPL-2.1</a> (engine); <a href="https://semgrep.dev/docs/licensing">Semgrep Rules License</a> (rules)</td></tr>
<tr><td><a href="https://www.zaproxy.org/">OWASP ZAP</a></td><td>DAST - mem-proxy dan memindai aplikasi yang berjalan dari dalam jaringan, UI desktop di <code>zap.test</code></td><td><code>ZAP_VERSION</code> = stable</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://trivy.dev/">Trivy</a></td><td>CVE/SCA atas image, filesystem, dan dependensi; laporan HTML disajikan <code>trivy.test</code></td><td><code>TRIVY_VERSION</code> = 0.58.1</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://github.com/tirth8205/code-review-graph">code-review-graph (CRG)</a></td><td>Graf intelejen kode AI; image scanner dibangun dari <code>configs/crg</code>, viewer di <code>crg.test</code></td><td><code>CRG_VERSION</code> = 2.3.7</td><td><a href="https://github.com/tirth8205/code-review-graph/blob/main/LICENSE">MIT</a></td></tr>
</tbody>
</table>

## Sistem host & alat CLI

<table>
<thead><tr><th>Proyek</th><th>Fungsinya di LDS</th><th>Versi (env)</th><th>Lisensi</th></tr></thead>
<tbody>
<tr><td><a href="https://www.docker.com/">Docker</a> + Compose</td><td>Menjalankan seluruh stack; Compose menggerakkan <code>lds up</code>, profil, dan healthcheck</td><td>Docker Desktop / Engine di host</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://git-scm.com/">Git</a></td><td>Kontrol versi untuk repositori ini, dan skrip scaffolding menyalin template dengannya</td><td>host</td><td><a href="https://git-scm.com/about/free-and-open-source">GPL-2.0</a></td></tr>
<tr><td>Bash (Git Bash di Windows)</td><td>Menjalankan <code>lds.sh</code> dan semua <code>scripts/*.sh</code></td><td>host</td><td><a href="https://www.gnu.org/licenses/gpl-3.0.en.html">GPL-3.0</a></td></tr>
<tr><td>PowerShell + cmd</td><td>Menjalankan kembaran <code>.bat</code> dari skrip di Windows</td><td>host</td><td>PowerShell <a href="https://github.com/PowerShell/PowerShell/blob/master/LICENSE.txt">MIT</a>; cmd bagian dari Windows</td></tr>
<tr><td><a href="https://github.com/FiloSottile/mkcert">mkcert</a></td><td><code>lds certs</code> membuat sertifikat wildcard <code>*.test</code> yang dipercaya lokal (jalur utama)</td><td>host (opsional)</td><td><a href="https://github.com/FiloSottile/mkcert/blob/master/LICENSE">MIT</a></td></tr>
<tr><td><a href="https://www.openssl.org/">OpenSSL</a></td><td>Sertifikat self-signed cadangan saat mkcert tidak terpasang</td><td>host</td><td><a href="https://www.openssl.org/source/license.html">Apache-2.0</a></td></tr>
<tr><td><a href="https://curl.se/">curl</a></td><td>Mengunduh driver JDBC, DuckDB, Maven, dan plugin Connect di sepanjang skrip</td><td>host</td><td><a href="https://curl.se/docs/copyright.html">lisensi curl (mirip MIT)</a></td></tr>
</tbody>
</table>

## Dibundel di repositori ini

<table>
<thead><tr><th>Proyek</th><th>Fungsinya di LDS</th><th>Versi (env)</th><th>Lisensi</th></tr></thead>
<tbody>
<tr><td><a href="https://github.com/erusev/parsedown">Parsedown</a></td><td>Markdown ke HTML untuk halaman handbook (<code>docs.php</code>), ditambal untuk deprecation implicit-nullable PHP 8.4</td><td>1.7.4 (<code>configs/web/dashboard/lib/</code>)</td><td><a href="https://github.com/erusev/parsedown/blob/master/LICENSE.txt">MIT</a> (<code>lib/PARSEDOWN-LICENSE.txt</code>)</td></tr>
<tr><td><a href="https://github.com/aptible/supercronic">supercronic</a></td><td>Cron aman container yang dibakar ke base dev dan dibundel untuk image cron cloud</td><td>v0.2.46 (<code>assets/supersonic/</code>)</td><td><a href="https://github.com/aptible/supercronic/blob/main/LICENSE.md">MIT</a></td></tr>
<tr><td>CLI DuckDB</td><td>Binary yang dipakai skrip bantu dan seed lokal</td><td>1.2.0 (<code>assets/duckdb/</code>)</td><td><a href="https://github.com/duckdb/duckdb/blob/main/LICENSE">MIT</a></td></tr>
<tr><td>Jar driver JDBC</td><td>Binary yang diunduh tiap developer (di-git-ignore); Hop dan Hive memasangnya single-file</td><td>dikunci per jar (<code>assets/jdbc/</code>)</td><td>Campuran - lihat <code>assets/jdbc/README.md</code> di tabel Data di atas</td></tr>
<tr><td>Aset brand LDS</td><td>Logo, badge, dan ikon di <code>assets/brand/</code> - digambar untuk proyek ini</td><td>-</td><td>Dibuat untuk LDS (tanpa merek pihak ketiga)</td></tr>
</tbody>
</table>

## Image dasar template & pembantu (build cloud)

Template membawa Dockerfile kedua untuk build cloud/default (K8s, Fleet, CI).
Tag-tag ini ditulis tetap di template, bukan lewat env.

<table>
<thead><tr><th>Image</th><th>Dipakai oleh</th><th>Versi (env)</th><th>Lisensi</th></tr></thead>
<tbody>
<tr><td><a href="https://hub.docker.com/_/tomcat">tomcat</a></td><td>Template servlet Java <code>svc</code>/<code>web</code></td><td>10.1-jdk21</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://hub.docker.com/_/php">php</a></td><td>Image cloud <code>cron-php</code></td><td>8.4-cli-alpine</td><td><a href="https://www.php.net/license/3_01.txt">PHP-3.01</a></td></tr>
<tr><td><a href="https://hub.docker.com/_/golang">golang</a></td><td>Image cloud <code>cron-go</code> (tahap build)</td><td>1.25-alpine</td><td><a href="https://go.dev/LICENSE">BSD-3-Clause</a></td></tr>
<tr><td><a href="https://hub.docker.com/_/node">node</a></td><td>Image cloud <code>cron-node</code></td><td>22-alpine</td><td><a href="https://github.com/nodejs/node/blob/main/LICENSE">MIT</a></td></tr>
<tr><td><a href="https://hub.docker.com/_/python">python</a></td><td>Image cloud <code>cron-python</code> dan scanner CRG</td><td>3.12-slim</td><td><a href="https://docs.python.org/3/license.html">PSF-2.0</a></td></tr>
<tr><td><a href="https://hub.docker.com/_/alpine">alpine</a></td><td>Image cloud <code>cron-shell</code></td><td>3.20</td><td>Campuran (per paket)</td></tr>
<tr><td><a href="https://hub.docker.com/_/debian">debian</a></td><td><code>base-images/php</code> dan image pembantu DuckDB</td><td>13-slim</td><td><a href="https://www.debian.org/legal/">Campuran (per paket)</a></td></tr>
</tbody>
</table>

> Layanan milik LDS sendiri - panel kontrol, pembangkit connector, image DNS,
> skrip seed dan init, aplikasi analytics/tasks/wiki, serta utilitas Text diff +
> Palette generator di <code>configs/web/dashboard/tools/</code> - ditulis di
> repositori ini dan tidak membawa lisensi pihak ketiga. Semua yang di atas
> dicantumkan karena bukan milik kita. Versi bisa berubah: nilai bawaan yang
> otoritatif ada di `.env.example` dan `docker-compose.yml`.
