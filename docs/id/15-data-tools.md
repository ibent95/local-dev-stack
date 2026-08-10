# 15 · Dashboard & tool data

Halaman ini membahas **panel kontrol** di `http://localhost` serta profile tool
mandiri yang ditambahkan di atas stack inti: **DrawDB** (perancangan skema),
**Apache Hop** + **Apache Superset** (data warehouse & BI), **DuckDB** + **Trino**
(mesin query analitis), **Semgrep** + **OWASP ZAP** + **Trivy** (pemindaian kode
& kerentanan), **code-review-graph** (kecerdasan kode AI),
**Vaultwarden** (password manager), **Mailpit** (SMTP + inbox), **Penpot**
(desain), **Instatic** (visual CMS), **OpenWA** (API WhatsApp), **RustFS**
(berbagi file), **HeadlessX** (automasi browser anti-deteksi), **Playwright**
(pengujian End-To-End), **aplikasi LDS** (Analytics, Tasks, Wiki), dan
**ERPNext** (ERP di atas Frappe). Dua browser layanan pendukung, `phpcacheadmin` dan `dbgate`,
didokumentasikan di [13 · Profile](13-profiles.md).

## Panel kontrol — `http://localhost`

Container PHP melayani panel kontrol sebagai situs default-nya, dapat diakses di
**`http://localhost`** (tanpa perlu entri hosts). Dibuat oleh
`configs/web/dashboard/index.php` dan menampilkan, secara langsung:

- **Tool & UI web**, dikelompokkan — *Data management* (phpCacheAdmin, DBGate,
  Kafka UI, Connector builder), *File storage* (RustFS), *Documents &
  credentials* (Tasks, Wiki, Vaultwarden), *Messaging / Socials* (Mailpit,
  OpenWA), *Browser automation & scraping* (HeadlessX), *Design* (Penpot,
  DrawDB), *Websites & CMS* (Instatic), *ERP & business* (ERPNext), *Analytic &
  Business intelligence* (Analytics, Hop, Trino, Superset), *Code & security
  quality scanner* (Semgrep, Trivy, ZAP, code-review-graph), *Testing tools*
  (Playwright), dan *Websockets monitoring* (Centrifugo, MQTTX) —
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

- **Buka di `http://localhost:4502`** — **bukan** `drawdb.test`.
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

### OWASP ZAP — `zap.test` / `localhost:4510`

Dynamic Application Security Testing terhadap aplikasi yang **live**. UI desktop
ZAP penuh berjalan di browser (WebSwing): nyalakan dengan
**`lds up proxy zap`** (atau `php zap`) — ZAP butuh **proxy** berjalan, yang
merutekan `zap.test` *dan* membawa container `dns` di balik view DNS in-network-
ya — lalu buka **`zap.test/zap`** (port proxy/API ZAP `:4512`)
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

### Trivy — `trivy.test` / `localhost:4511`

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

## Code intelligence — code-review-graph

**Profile:** `crg` (`LDS_ENABLE_CRG`). **Mati secara default.**

Graf kecerdasan-kode **AI yang local-first** (`tirth8205/code-review-graph`):
Tree-sitter mengurai repo menjadi graf SQLite persisten (fungsi, kelas, import,
panggilan), lalu menjawab pertanyaan blast-radius — "apa yang terpengaruh oleh
perubahan ini?" — sehingga tool AI coding (Claude Code, Codex, Cursor, Gemini,
Copilot, …) hanya membaca file yang relevan (~65× lebih sedikit token pada
review). Integrasi AI/MCP sudah bawaan; grafnya sendiri tetap di mesin Anda.

Pola dua-bagian sama seperti Semgrep/Trivy: viewer (`crg` — yang dijalankan
`lds up crg`) + image scanner sekali-jalan (`lds/crg`, dibangun dari
`configs/crg` — upstream tidak menyediakan image resmi).

```sh
lds up crg                    # jalankan viewer laporan (ikut membangun image scanner)
lds tools crg <path>          # bangun graf + ekspor HTML interaktif
lds tools crg <path> myapp    # nama kustom untuk URL viewer (default: nama folder)
lds tools crg clear           # hapus semua laporan dari viewer
```

- **Viewer:** `http://crg.test/<nama>/` (`localhost:4530`) — graf force-directed
  D3 interaktif (pencarian, legenda komunitas, node berskala-derajat). Halaman
  landing mendaftar folder laporan; `lds up crg` harus berjalan.
- **Di dalam repo yang dipindai** graf DB + HTML berada di `.code-review-graph/`
  (auto-gitignored), jadi memindai ulang repo yang sama bersifat **inkremental**
  — hanya file yang berubah yang di-parse ulang.
- **Local-first:** tidak ada yang diunggah. Embedding semantic-search opsional
  dan server MCP berjalan di **host** Anda jika diinginkan:
  `pip install code-review-graph && code-review-graph install` (mengonfigurasi
  otomatis semua tool AI yang didukung), atau arahkan konfigurasi MCP tool Anda
  ke `docker run -v <repo>:/src -w /src lds/crg:2.3.7 serve` untuk endpoint
  kontainer.
- **Windows:** skrip me-mount repo dengan path drive-letter via `docker run`
  (caveat pemecahan colon `-v` Compose dari Semgrep berlaku di sini juga).

## Web analytics — LDS Analytics

**Profile:** `analytics` (`LDS_ENABLE_ANALYTICS`). **Mati secara default.**

Web analytics self-hosted (frontend Nuxt/Vue + API Hono) yang ditambahkan ringan di atas stack inti.

- Reuse **`lds-postgres`** bersama (tanpa container Postgres khusus analytics).
- UI: `http://localhost:4521` / `analytics.test`
- API: `http://localhost:4520`
- Bootstrap DB otomatis saat profile ini start (`analytics-init` →
  `postgres-init`).

## Security & auth — Vaultwarden

**Profile:** `vaultwarden` (`LDS_ENABLE_VAULTWARDEN`). **Mati secara default.**

Password manager self-hosted (server + web vault kompatibel Bitwarden).

- URL: `http://localhost:4506` / `vaultwarden.test`
- Storage persisten: volume `vaultwarden-data` (sqlite).
- Signup default nonaktif (`VAULTWARDEN_SIGNUPS_ALLOWED=false`).

## Mail — Mailpit

**Profile:** `mail` (`LDS_ENABLE_MAIL`). **Mati secara default.**

SMTP sink lokal + inbox web untuk uji email aman (workflow lokal ala Mailchimp):

- Web inbox: `http://localhost:4513` / `mail.test`
- Endpoint SMTP: `localhost:4514` (container `1025`)
- Data persisten: `data/mailpit/`

## Design — Penpot

**Profile:** `penpot` (`LDS_ENABLE_PENPOT`). **Mati secara default.**

Tool desain kolaboratif self-hosted:

- URL: `http://localhost:4518` / `penpot.test`
- Service: `penpot-frontend`, `penpot-backend`, `penpot-exporter`
- Reuse `postgres` + `valkey` (default DB/user: `app` / `app`)

## Project management — LDS Tasks

**Profile:** `tasks` (`LDS_ENABLE_TASKS`). **Mati secara default.**

Aplikasi project management/kolaborasi tim self-hosted (frontend Angular + API Hono).

- Reuse **`lds-postgres`** bersama (tanpa container Postgres khusus tasks).
- UI: `http://localhost:4523` / `tasks.test`
- API: `http://localhost:4522`
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

## Dokumentasi — LDS Wiki

**Profile:** `wiki` (`LDS_ENABLE_WIKI`). **Mati secara default.**

Aplikasi wiki/dokumentasi self-hosted (frontend Next.js + API Hono).

- Reuse **`lds-postgres`** bersama (tanpa container Postgres khusus wiki).
- UI: `http://localhost:4525` / `wiki.test`
- API: `http://localhost:4524`
- Bootstrap DB otomatis saat profile ini start (`wiki-init` → `postgres-init`).

## Automasi browser — HeadlessX

**Profile:** `headlessx` (`LDS_ENABLE_HEADLESSX`). **Mati secara default.**

Platform automasi browser anti-deteksi / scraping self-hosted — dashboard
Next.js, Express API + worker antrean, **endpoint MCP** jarak jauh, ditenagai
runtime Firefox yang di-patch (Camoufox) untuk deteksi ~0%.

- **UI:** `http://headlessx.test` / `localhost:4515` — dashboard, playground
  (operator Website, Google AI Search, Tavily, Exa, YouTube), API keys, job &
  log antrean.
- **API / MCP:** `http://headlessx-api.test` / `localhost:4516`. Semua rute
  non-health dilindungi `x-api-key` (buat key di halaman *API Keys* dashboard —
  jangan pakai key internal dashboard untuk MCP). Dashboard mem-proxy `/api/*`
  secara internal, jadi browser hanya bicara ke `headlessx.test`.
- **Memakai ulang stack bersama** — LDS Postgres (DB `lds_headlessx`, dibuat
  otomatis via `POSTGRES_INIT_SPECS`) dan LDS Redis (DB logis `4`) untuk antrean
  BullMQ. Tanpa container DB/redis khusus.
- **Dibangun dari source:** tidak ada image yang dipublikasikan — service
  dibangun dari checkout lokal di `data/headlessx`. `lds up headlessx`
  auto-clone/update dulu (`lds headlessx init` / `lds headlessx update` untuk
  kontrol manual). `up` pertama membangun empat image (pnpm/nx + bundle browser)
  dan **lambat** — butuh beberapa menit dan beberapa GB RAM saat berjalan
  (api/worker default `1g` masing-masing).
- **Run pertama Google AI Search:** buka playground Google AI Search → **Build
  Cookies** → browsing sekali (selesaikan reCAPTCHA bila ada) → **Stop Browser**.
  Sesi tersimpan di volume `headlessx-browser-profile` dan dipakai ulang.
- **Volume persisten:** `headlessx-browser-profile` (sesi browser tersimpan),
  `headlessx-models` (model ONNX captcha), `headlessx-yt-engine-tmp`.

## Pengujian End-To-End — Playwright

**Profile:** `playwright` (`LDS_ENABLE_PLAYWRIGHT`). **Mati secara default.**

Tes End-To-End berbasis browser terhadap aplikasi stack Anda — container runner
Playwright yang hangat (image resmi, Chromium + Firefox + WebKit terpasang)
yang bergabung ke **DNS in-network**, sehingga browser-nya menghantam layanan
`http://<app>.test` melalui proxy seperti browser host.

```bash
lds up playwright              # pull + start runner dan viewer laporan
lds playwright init myapp      # scaffold proyek (target http://myapp.test secara default)
lds playwright init myapp http://myapp.test   # atau arahkan ke aplikasi *.test mana pun
lds playwright run myapp       # jalankan tesnya (menulis laporan HTML)
lds playwright run myapp -- --project=chromium   # argumen CLI playwright tambahan
lds playwright codegen http://myapp.test   # rekam tes secara visual (butuh TTY)
lds playwright ui myapp        # UI Mode interaktif — buka http://localhost:4527 di browser
lds playwright shell           # buka shell di container runner
```

- **Proyek:** `data/playwright/projects/<nama>/` (masing-masing dengan
  `playwright.config.ts` + `tests/` sendiri). `init` meng-pin `@playwright/test`
  ke versi Playwright image runner dan menulis ulang URL target.
- **Laporan:** setiap run menulis laporan HTML ke
  `data/playwright/reports/<nama>/`, disajikan viewer di
  `http://playwright.test/<nama>` (`localhost:4526`).
- **UI Mode (browser):** `lds playwright ui <nama>` menyajikan UI interaktif
  Playwright — watch mode, jalankan/filter tes, time-travel debugging — di
  `http://localhost:4527`. UI-nya web app yang dibuka di **browser host**;
  tesnya sendiri berjalan di browser headless container.
- **Run pertama** di proyek baru menjalankan `npm install` di dalam container;
  browser sudah ada di image — tanpa `npx playwright install`.
- **Berat:** image runner memuat ketiga browser (~1.5 GB).

## Website & CMS — Instatic

**Profile:** `instatic` (`LDS_ENABLE_INSTATIC`). **Mati secara default.**

**Visual CMS / website builder** self-hosted (`corebunch/instatic`, MIT) —
alternatif open-source Webflow/Framer/WordPress. Editor canvas dengan frame
breakpoint, design tokens (Core Framework), komponen yang bisa dipakai ulang,
loops, form, agen AI yang mengedit halaman (bawa model sendiri — Claude, OpenAI,
atau Ollama lokal), dan publisher yang mengeluarkan HTML/CSS statis bersih.
Satu server Bun, image resmi.

- **UI:** `http://instatic.test` (`localhost:4528`) — kunjungan pertama memandu
  Anda membuat situs + akun pemilik; admin berada di `/admin`.
- **Persistensi:** `data/instatic/` — `data/` (SQLite `cms.db`) + `uploads/`.
  Backup dua folder itu berarti backup situsnya.
- **Database:** SQLite secara default. Untuk tim penulis, setel
  `INSTATIC_DATABASE_URL=postgres://app:app@postgres:5432/lds_instatic` (buat DB
  dulu: `lds db init postgres`).
- **Di balik proxy:** `INSTATIC_TRUSTED_PROXY_CIDRS=0.0.0.0/0` (dev) agar proxy
  edge LDS dipercaya.
- **Catatan:** upstream masih pre-1.0 (0.0.x) — "early on purpose"; API bisa
  berubah. Di-pin ke `INSTATIC_VERSION=0.0.14` (naikkan di `.env` saat rilis
  baru; tag image sama dengan tag rilis GitHub tanpa `v`).

## ERP & bisnis — ERPNext

**Profile:** `erpnext` (`LDS_ENABLE_ERPNEXT`). **Mati secara default.** **Berat.**

Paket **ERP lengkap di atas framework Frappe** (`frappe/erpnext`, GPL-3.0) —
Accounting, CRM, HR, Inventory, Manufacturing, eCommerce, dan lainnya, dengan
seluruh admin web di `erpnext.test`.

```sh
lds up erpnext               # pull ~4-8 GB image + bootstrap situs (beberapa menit)
```

Boot pertama menjalankan dua service bootstrap sekali-jalan
(`erpnext-configurator` menulis `sites/common_site_config.json`,
`erpnext-create-site` menjalankan `bench new-site --install-app erpnext`);
`up` berikutnya melewatinya. Login: **`Administrator`** / `ERPNEXT_ADMIN_PASSWORD`
(default `admin`).

- **Memakai ulang stack bersama:** database = **`lds-postgres`** bersama secara
  default (`ERPNEXT_DB_TYPE=postgres` — port Postgres ERPNext mendarat di
  upstream tahun 2026, jadi ini jalur modern; DB + role situs dibuat saat boot
  pertama). Alternatif yang teruji upstream adalah `ERPNEXT_DB_TYPE=mariadb`
  terhadap **`lds-mariadb`** bersama (aktifkan: `LDS_ENABLE_MARIADB=true` atau
  `lds up mariadb erpnext`). Cache/antrean = **`lds-redis`** bersama di DB logis
  `5`/`6` (`ERPNEXT_REDIS_CACHE_DB` / `ERPNEXT_REDIS_QUEUE_DB` — sesuaikan bila
  bertabrakan dengan tenant lain). `lds up erpnext` otomatis membawa postgres +
  redis.
- **Service:** `erpnext-backend` (gunicorn), `erpnext-frontend` (nginx,
  `erpnext.test` / `localhost:4529`), `erpnext-worker` + `erpnext-worker-long`
  (antrean background), `erpnext-scheduler`, `erpnext-websocket` (Socket.IO),
  plus dua service bootstrap sekali-jalan (`erpnext-configurator`,
  `erpnext-create-site`).
- **Persistensi:** `data/erpnext/` — `sites/`, `logs/`. Di Linux, buat direktori
  itu dapat ditulis user `frappe` (uid 1000) bila pembuatan situs gagal karena
  permission.
- **Sumber daya:** ~3-6 GB RAM di seluruh service; setiap batas mem bisa diatur
  di `.env` (`ERPNEXT_*_MEM_LIMIT`). Hentikan dengan `lds stop erpnext`.
- **Versi:** `ERPNEXT_VERSION=16.31.1` (jalur Frappe `v16`). Pin versi sama
  untuk semua service — mereka berbagi satu tag image.
- **Caveat Postgres:** dukungan Postgres ERPNext resmi tetapi baru (port 2026,
  ~4.200 query diaudit). Alur inti accounting/CRM/HR adalah permukaan yang
  teruji; sebagian laporan atau modul long-tail mungkin masih menemui sisi kasar.
  Itulah trade-off tidak menjalankan database khusus — balik
  `ERPNEXT_DB_TYPE=mariadb` jika ada yang bermasalah.

---

Lihat [12 · Port](12-ports.md) untuk peta port host dan
[13 · Profile](13-profiles.md) untuk setiap profile secara rinci.
