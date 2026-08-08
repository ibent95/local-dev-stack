# 15 · Dashboard & tool data

Halaman ini membahas **panel kontrol** di `http://localhost` serta profile tool
mandiri yang ditambahkan di atas stack inti: **DrawDB** (perancangan skema),
**Apache Hop** + **Apache Superset** (data warehouse & BI), **Semgrep** +
**OWASP ZAP** + **Trivy** (pemindaian kode & kerentanan),
**Vaultwarden** (password manager),
dan **LDS Wiki** (dokumentasi). Dua browser layanan pendukung, `phpcacheadmin` dan `dbgate`,
didokumentasikan di [13 · Profile](13-profiles.md).

## Panel kontrol — `http://localhost`

Container PHP melayani panel kontrol sebagai situs default-nya, dapat diakses di
**`http://localhost`** (tanpa perlu entri hosts). Dibuat oleh
`configs/web/dashboard/index.php` dan menampilkan, secara langsung:

- **Tool & UI web**, dikelompokkan — *Admin tools* (phpCacheAdmin, DBGate),
  *Auth* (Vaultwarden), *Communication tools* (Mailpit, OpenWA), *Designers*
  (Penpot, DrawDB), *Data tools* (Superset, Hop), *Code quality* (Semgrep),
  *Security tools* (ZAP, Trivy), *LDS apps* (Analytics, Tasks, Wiki), *Kafka
  tools* (Kafka UI, Connector builder), *Analytical query engines* (DuckDB, Trino),
  *Realtime dashboards* (Centrifugo, MQTTX), dan *Storage tools* (RustFS) —
  masing-masing dengan titik ●/○ status keterjangkauan.
- **Proyek** — setiap folder di `${PHP_PROJECTS_PATH}`, ditautkan ke host
  `<nama>.test`-nya.
- **Layanan pendukung** — MySQL/Postgres/Mongo/Redis/Memcached/Kafka/broker,
  diperiksa hidup/mati.

> Dilayani dari `/var/lds-dashboard` (di-mount **di luar** path proyek), jadi
> **bukan** sebuah proyek — tidak ada `__dashboard.test`, dan tak pernah muncul
> di daftar proyek. Tautan dan pengelompokan di sini mengikuti keluaran
> `lds hosts-sync`.

## Database design — DrawDB

**Profile:** `drawdb` (`LDS_ENABLE_DRAWDB`). **Mati secara default.**

Perancang skema database / diagram ER berbasis browser. SPA statis — diagram
disimpan di browser Anda (tanpa DB server). Image upstream
`ghcr.io/drawdb-io/drawdb` (di-pin di `.env`), satu container ringan.

- **Buka di `http://localhost:4462`** — **bukan** `drawdb.test`.
  DrawDB memanggil `crypto.randomUUID()`, yang hanya tersedia di browser pada
  **secure context** (HTTPS atau `localhost`/`127.0.0.1`). Lewat
  `http://drawdb.test` biasa fungsi itu `undefined` dan aplikasi tampil kosong.
  Pakai port `localhost`, atau sajikan stack via HTTPS (`LDS_ENABLE_HTTPS=true`)
  untuk memakai `https://drawdb.test`.

## Data warehouse & BI — Apache Hop & Apache Superset

**Profile:** `hop` (`LDS_ENABLE_HOP`), `superset` (`LDS_ENABLE_SUPERSET`). **Mati
secara default.** Keduanya terhubung ke DB stack sebagai sumber data — dari dalam
jaringan pakai nama container (`lds-postgres:5432`, `lds-mysql:3306`).

### Apache Hop — `hop.test`

**Perancang pipeline ETL / integrasi data** berbasis browser (Hop Web).

- **Image:** `apache/hop-web` (Tomcat) — **bukan** `apache/hop`, yang merupakan
  `hop-server` headless dan memaksa HTTP Basic auth (`cluster`/`cluster`).
- **Tanpa login.** Disajikan di `/ui`; aplikasi mengarahkan `/` → `/ui` sendiri,
  jadi `hop.test` langsung membuka perancang. (`/ui` **tanpa** garis miring akhir —
  `/ui/` adalah 404.)
- **Driver MySQL.** Hop menyertakan banyak driver JDBC (Postgres, MSSQL, …) tapi
  **bukan** MySQL Connector/J (GPL). Ditambahkan via mount satu berkas dari
  `assets/jdbc/` — lihat README di sana untuk mengambil ulang jar
  (`HOP_MYSQL_DRIVER` di `.env`). Postgres tak butuh apa-apa; Kafka pakai
  *transforms* bawaan Hop (bukan JDBC); MongoDB/Redis tak punya driver JDBC.
- **Tanpa timeout sesi.** Hop Web (Eclipse RAP) mengikat kanvas ke sesi HTTP;
  kami ubah timeout default 30 menit Tomcat menjadi *tak pernah* agar Anda tak
  kena "session timed out" di tengah kerja (wrapper `command` pada service).
- **Persistensi:** dua direktori host yang di-mount (`data/hop/config`
  dan `data/hop/audit`) menyimpan proyek, koneksi, dan preferensi
  pengguna lintas restart dan recreate container. Pipeline dan workflow Anda
  berada langsung di disk — telusuri, edit, atau version-control tanpa menyentuh
  container. Hanya subdirektori data pengguna yang di-mount — aplikasi Hop itu
  sendiri selalu berasal dari image, jadi upgrade image berjalan bersih. Gunakan
  `down -v` untuk menghapus direktori dan mulai dari awal.
- **Folder-per-project.** Buat proyek Hop baru dengan:
  ```sh
  lds new hop my-etl-project
  ```
  Ini membuat direktori di bawah `HOP_PROJECTS_PATH` (default `data/hop/projects/`)
  dengan `project-config.json`, plus subdirektori `metadata/`, `pipelines/`,
  `workflows/`, dan `datasets/`. Saat `lds up hop` berjalan, script `hop-register`
  (otomatis dijalankan post-up) mendaftarkan setiap folder proyek di `hop-config.json`
  Hop via `hop-conf` di dalam container. Pipeline dan workflow Anda berada di disk
  — version-control dengan git langsung.

### Apache Superset — `superset.test`

**Dashboard & pelaporan BI.** Login **`admin` / `admin`**.

- **Image:** Docker Hardened Image `${DHI_REGISTRY}/superset` — varian runtime
  non-dev, nonroot (UID 65532).
- **Inisialisasi sendiri saat start** (db upgrade → buat admin → init → gunicorn),
  dijalankan dari Python venv image karena image hardened tak punya shell.
- **Metadata** berupa SQLite di direktori host yang di-mount (`data/superset/`)
  — cukup untuk dev. Di Linux, direktori host harus dapat ditulis oleh UID 65532
  (user nonroot DHI); jika Anda kena *"attempt to write a readonly database"*,
  perbaiki dengan `chown 65532:65532 data/superset` (di Windows Docker
  Desktop ini bukan masalah). Login **`admin` / `admin`**. Data hidup langsung
  di disk via bind mount — seperti mekanisme proyek Hop, tanpa perlu
  export/import. Superset membaca dan menulis ke `data/superset/` langsung.

## Code quality — Semgrep

**Profile:** `semgrep` (`LDS_ENABLE_SEMGREP`). **Mati secara default.**

Pemindai analisis statis (SAST) dengan viewer SARIF yang ringan. Terdiri dari
dua service compose:

- **`semgrep`** (profile `semgrep`, `all`) — **viewer**: nginx kecil yang
  menyajikan `data/semgrep/reports/` di `semgrep.test`. Inilah yang dijalankan
  `lds up semgrep`.
- **`semgrep-scan`** (profile `semgrep-scan`) — **scanner**: image CLI
  `semgrep/semgrep` yang dipin, dideklarasikan di compose agar terversi.
  Sekali-jalan, jadi berada di profile sendiri dan **tidak pernah auto-start**
  pada `lds up`/`all` (tak ada container Exited yang menggantung). `lds up semgrep`
  **pre-pull** image ini (best-effort), jadi scanner ikut dengan profile tanpa
  menjadi service yang berjalan; atau pull langsung dengan
  `docker compose --profile semgrep-scan pull semgrep-scan`.

Jalankan scan:

```sh
lds tools semgrep [path]      # default: direktori saat ini, ruleset SEMGREP_RULES (p/default)
lds tools semgrep clear       # hapus SARIF + metadata dari viewer
```

Itu menjalankan image `semgrep-scan` yang dipin dengan `docker run -v <path>:/src`
dan menulis `data/semgrep/reports/report.sarif` ke folder yang disajikan
viewer. (Memakai `docker run`, bukan `docker compose run`, karena parser `-v`
Compose memecah pada `:` dan gagal pada path drive Windows seperti `D:\…`.)
Segarkan **`semgrep.test`** dan viewer menampilkan temuan (filter per severity /
cari), termasuk metadata project terakhir yang dipindai dan tombol **Clear**.
Tanpa DB; sebelum Anda menjalankan scan, belum ada `report.sarif`.

Ruleset default **`p/default`**, dijalankan dengan telemetri **off**. Pilih lain
via `SEMGREP_RULES` — pack registry mana pun (`p/php`, `p/security-audit`,
`p/ci`), URL rules, atau YAML lokal; semua jalan dengan metrics off. `auto` juga
valid tapi **wajib metrics on** (mengunggah metadata proyek ke semgrep.dev untuk
memilih rules), dan unggahan akhir itu bisa menggantung pada koneksi
lambat/offline — jadi skrip hanya menyalakan metrics bila Anda set
`SEMGREP_RULES=auto`. (Pack registry tetap diambil via jaringan saat scan mulai;
itu waktu muat, bukan macet.)

## Pemindaian kerentanan — OWASP ZAP & Trivy

**Profile:** `zap` (`LDS_ENABLE_ZAP`), `trivy` (`LDS_ENABLE_TRIVY`). **Mati secara
default.** Dua pemindai yang melengkapi Semgrep (SAST, kode sumber):

| Tool | Yang dipindai | Cara |
|---|---|---|
| **Semgrep** (SAST) | kode sumber, untuk pola bug | `lds tools semgrep [path]` |
| **OWASP ZAP** (DAST) | aplikasi `.test` yang **berjalan** (SQLi, XSS, SSRF, auth, …) | UI browser di `zap.test/zap` |
| **Trivy** (SCA) | container, filesystem, git repo, manifest dependensi | `lds tools trivy [path]` / `lds tools trivy image <name>` |

### OWASP ZAP — `zap.test` / `localhost:4470`

Dynamic Application Security Testing terhadap aplikasi yang **live**. UI desktop
ZAP penuh berjalan di browser (WebSwing): nyalakan dengan
**`lds up proxy zap`** (atau `php zap`) — ZAP butuh **proxy** berjalan, yang
merutekan `zap.test` *dan* membawa container `dns` di balik view DNS in-network-
ya — lalu buka **`zap.test/zap`** (port proxy/API ZAP `:4472`)
dan pindai aplikasi lokal dengan **`http://<folder>.test`** sebagai target.

- **DNS in-network gratis.** ZAP me-resolve `*.test` melalui view *in-network*
  container dns (`10.99.0.53` di `lds-dnsnet`), yang menjawab `*.test` dengan
  **IP container proxy** — jadi `http://myapp.test` mencapai vhost yang tepat
  dari dalam container, sementara dnsmasq yang menghadap host tetap menjawab
  `127.0.0.1` untuk browser Anda. (Jika container dns mati, ZAP jatuh ke DNS
  embedded Docker — nama container + internet tetap resolve; hanya aplikasi
  `.test` yang butuh proxy hidup.)
- **Setelah memperbarui stack**, rebuild image `dns` sekali agar view in-network
  ada: `lds up --rebuild proxy` (atau `docker compose build dns`) — image basi
  tetap memakai perilaku single-dnsmasq lama.
- **ZAP mulai lambat:** kunjungan pertama ke `zap.test` butuh sesaat saat ZAP
  boot di dalam UI.
- **Persistensi:** file runtime ZAP di-bind ke `data/zap/` (`/zap/wrk` +
  `/home/zap`) sehingga cert/sesi tetap ada saat container dibuat ulang.
- **Berat:** berbasis Java, dibatasi ~2 GB (`ZAP_MEM_LIMIT`). Jalankan hanya saat
  Anda benar-benar memindai.
- `ZAP_VERSION` default ke tag `stable` yang berjalan — pin versi tertentu di
  `.env` untuk reproduksibilitas.

> Pemindaian membutuhkan aplikasi target **berjalan** — nyalakan proyeknya dulu
> (`lds up` dengan profile-nya), lalu arahkan ZAP ke aplikasi itu.

### Trivy — `trivy.test` / `localhost:4471`

Pemindaian CVE yang dikenal (SCA) terhadap *artefak*, bukan aplikasi live:
image container, filesystem, git repo, dan manifest dependensi (`composer.lock`,
`package-lock.json`, `go.sum`, …). Pola dua service sama seperti Semgrep: viewer
(`trivy` — yang dijalankan `lds up trivy`) + scanner sekali-jalan
(`trivy-scan`, di profile sendiri sehingga tidak pernah auto-start).

```sh
lds tools trivy [path]        # scan fs — direktori, repo, atau manifest dependensi
lds tools trivy image <name>  # scan image — mis. lds/php:8.4 (memakai docker socket)
lds tools trivy clear         # hapus report + metadata dari viewer
```

Menulis `data/trivy/reports/report.html`, disajikan di **`trivy.test`**. DB
kerentanan di-cache di `data/trivy/cache` (dibagi dengan service compose),
sehingga scan pertama mengunduhnya dan scan berikutnya berjalan cepat. Viewer
menampilkan metadata target pemindaian dan tombol **Clear**. Seperti Semgrep,
skrip memakai `docker run` (bukan `docker compose run`) agar path Windows dengan
drive letter ter-mount dengan benar.

## Web analytics — LDS Analytics**Profile:** `analytics` (`LDS_ENABLE_ANALYTICS`). **Mati secara default.**

Web analytics self-hosted (frontend Nuxt/Vue + API Hono) yang ditambahkan ringan di atas stack inti.

- Reuse **`lds-postgres`** bersama (tanpa container Postgres khusus analytics).
- UI: `http://localhost:4427` / `analytics.test`
- API: `http://localhost:4428`
- Bootstrap DB otomatis saat profile ini start (`analytics-init` →
  `postgres-init`).

## Security & auth — Vaultwarden

**Profile:** `vaultwarden` (`LDS_ENABLE_VAULTWARDEN`). **Mati secara default.**

Password manager self-hosted (server + web vault kompatibel Bitwarden).

- URL: `http://localhost:4429` / `vaultwarden.test`
- Storage persisten: volume `vaultwarden-data` (sqlite).
- Signup default nonaktif (`VAULTWARDEN_SIGNUPS_ALLOWED=false`).

## Mail — Mailpit

**Profile:** `mail` (`LDS_ENABLE_MAIL`). **Mati secara default.**

SMTP sink lokal + inbox web untuk uji email aman (workflow lokal ala Mailchimp):

- Web inbox: `http://localhost:4473` / `mail.test`
- Endpoint SMTP: `localhost:4474` (container `1025`)
- Data persisten: `data/mailpit/`

## Design — Penpot

**Profile:** `penpot` (`LDS_ENABLE_PENPOT`). **Mati secara default.**

Tool desain kolaboratif self-hosted:

- URL: `http://localhost:4478` / `penpot.test`
- Service: `penpot-frontend`, `penpot-backend`, `penpot-exporter`
- Reuse `postgres` + `valkey` (default DB/user: `app` / `app`)

## Project management — LDS Tasks

**Profile:** `tasks` (`LDS_ENABLE_TASKS`). **Mati secara default.**

Aplikasi project management/kolaborasi tim self-hosted (frontend Angular + API Hono).

- Reuse **`lds-postgres`** bersama (tanpa container Postgres khusus tasks).
- UI: `http://localhost:4435` / `tasks.test`
- API: `http://localhost:4436`
- Bootstrap DB otomatis saat profile ini start (`tasks-init` → `postgres-init`).

## Analytical query engines — DuckDB & Trino

**Profile:** `duckdb` (`LDS_ENABLE_DUCKDB`), `trino` (`LDS_ENABLE_TRINO`). **Mati
secara default.** Dua mesin query analitis yang saling melengkapi untuk eksplorasi
data dan pelaporan.

### DuckDB — file engine (tanpa network port)

Embedded OLAP engine berjalan di base image **`lds/duckdev`** (DHI alpine-base
+ binary DuckDB CLI). DuckDB bersifat embedded seperti SQLite — tanpa server,
tanpa REST API. File `data.duckdb` disimpan di named volume persistent yang
dibagi dengan DBGate untuk akses GUI.

- **Tanpa network port:** DuckDB bukan server. Query via `docker exec`:
  ```sh
  docker exec -it lds-duckdb duckdb /data/data.duckdb
  docker exec lds-duckdb duckdb -c "SELECT * FROM read_parquet('/data/sales.parquet') LIMIT 10" /data/data.duckdb
  ```

- **Konektivitas DBGate:** Plugin DuckDB DBGate membuka file `data.duckdb` yang
  sama (read-only, di-mount dari shared volume `duckdb-data`). Tambah koneksi
  DuckDB di DBGate dengan path `/data/data.duckdb` dan mode **read-only**.

- **Direktori data:** `data/duckdb/` di host. Letakkan file `.parquet`, `.csv`,
  `.json`. Di dalam container muncul di `/data/`. Query dengan
  `read_parquet('/data/nama_file.parquet')`.

- **File database persistent:** File `data.duckdb` berada di Docker named volume
  `duckdb-data`. Bertahan setelah restart. Isi dengan:
  ```sh
  docker exec lds-duckdb duckdb /data/data.duckdb -c "CREATE TABLE sales AS SELECT * FROM read_parquet('/data/sales.parquet')"
  ```

- **Image:** `lds/duckdev:${DUCKDB_VERSION}` — build FROM DHI alpine-base,
  memasang binary DuckDB CLI official. Ringan — `${DUCKDB_MEM_LIMIT}`
  (default `256m`).

- **Seed data:** Jalankan `lds seed-data` untuk membuat sample file ke `data/duckdb/`.

### Trino — `localhost:4451`

Mesin SQL query terdistribusi penuh dengan UI web built-in. Query file Parquet
(melalui Hive connector dengan Hive Metastore), plus query federasi ke MySQL,
Postgres, Kafka, dan lainnya. ANSI SQL, eksekusi paralel, ekosistem konektor.

- **Web UI:** `http://localhost:4451/ui` — editor query, riwayat query,
  ringkasan cluster.
- **JDBC:** Hubungkan BI tools (Superset, Hop, Tableau) melalui driver JDBC
  Trino. String koneksi: `jdbc:trino://trino:8080/{catalog}/{schema}` (dalam
  jaringan Docker) atau `jdbc:trino://localhost:4451/{catalog}/{schema}` (dari host).

#### Menghubungkan Apache Superset ke Trino

1. Jalankan kedua profile: `./lds.sh up superset trino`
2. Buka Superset di `http://superset.test` (login `admin` / `admin`)
3. Buka **Data → Databases → + Database**
4. Pilih **Trino** dari dropdown
5. Masukkan **SQLAlchemy URI**:
   ```
   trino://trino:8080/hive/default
   ```
   (dari host, gunakan `trino://localhost:4451/hive/default`)
6. Klik **Test Connection** → **Save**

> Driver Python `trino` diinstal otomatis saat startup Superset melalui
> entrypoint (`pip install trino`). Tidak perlu langkah manual.

#### Menghubungkan Apache Hop ke Trino

Apache Hop terhubung ke Trino melalui JDBC menggunakan tipe **Generic database**.
Driver JDBC Trino (`trino-jdbc-483.jar`) di-mount ke container Hop dari
direktori bersama `assets/jdbc/`.

1. Ambil driver sekali:
   ```bash
   curl -fsSL -o assets/jdbc/trino-jdbc-483.jar \
     https://repo1.maven.org/maven2/io/trino/trino-jdbc/483/trino-jdbc-483.jar
   ```
2. Jalankan kedua profile: `./lds.sh up hop trino`
3. Buka Hop di `http://hop.test/ui`
4. Di perspektif **Metadata**, klik kanan **Relational Database Connections**
   → **New**
5. Isi:
   - **Connection Name:** `Trino`
   - **Connection Type:** `Generic`
   - **Access:** `Native (JDBC)`
   - **Driver Class:** `io.trino.jdbc.TrinoDriver`
   - **Custom Connection URL:** `jdbc:trino://trino:8080/hive/default`
6. Klik **Test** untuk verifikasi, lalu **Save**

- **Hive connector untuk Parquet:** Trino mengakses file Parquet melalui
  Hive Metastore. Daftarkan tabel via SQL `CREATE TABLE`:
  ```sql
  CREATE TABLE hive.parquet_schema.sales (
    date DATE,
    product VARCHAR,
    revenue DOUBLE
  ) WITH (
    format = 'PARQUET',
    external_location = 'local:///data/trino/sales/'
  );
  ```

- **Data sampel:** Trino dilengkapi dengan konektor `tpch` dan `tpcds` untuk
  pengujian:
  ```sql
  SELECT * FROM tpch.tiny.orders LIMIT 10;
  ```

- **Query federasi:** Query lintas semua sumber data LDS dalam satu SQL:
  ```sql
  SELECT * FROM tpch.tiny.orders o
  JOIN mysql.mysql_app.users u ON o.custkey = u.id;
  ```

- **Image:** Official `trinodb/trino:${TRINO_VERSION}`.
- **Metastore:** `hive-metastore` (official `apache/hive:4.0.0` image),
  otomatis berjalan dengan profile `trino`. Menggunakan Postgres LDS bersama
  (database `lds_hive_metastore`).

- **Direktori data:** `data/trino/` — file Parquet untuk query Trino.



---

## Dokumentasi — LDS Wiki

**Profile:** `wiki` (`LDS_ENABLE_WIKI`). **Mati secara default.**

Aplikasi wiki/dokumentasi self-hosted (frontend Next.js + API Hono).

- Reuse **`lds-postgres`** bersama (tanpa container Postgres khusus wiki).
- UI: `http://localhost:4437` / `wiki.test`
- API: `http://localhost:4438`
- Bootstrap DB otomatis saat profile ini start (`wiki-init` → `postgres-init`).

---

Lihat [12 · Port](12-ports.md) untuk peta port host dan
[13 · Profile](13-profiles.md) untuk setiap profile secara rinci.
