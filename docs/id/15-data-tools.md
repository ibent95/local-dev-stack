# 15 · Dashboard & tool data

Halaman ini membahas **panel kontrol** di `http://localhost` serta profile tool
mandiri yang ditambahkan di atas stack inti: **DrawDB** (perancangan skema),
**Apache Hop** + **Apache Superset** (data warehouse & BI), dan **Semgrep**
(kualitas kode). Dua browser layanan pendukung, `phpcacheadmin` dan `dbgate`,
didokumentasikan di [13 · Profile](13-profiles.md).

## Panel kontrol — `http://localhost`

Container PHP melayani panel kontrol sebagai situs default-nya, dapat diakses di
**`http://localhost`** (tanpa perlu entri hosts). Dibuat oleh
`configs/web/dashboard/index.php` dan menampilkan, secara langsung:

- **Tool & UI web**, dikelompokkan — *Data tools* (phpCacheAdmin, DBGate),
  *Database design* (DrawDB), *Data warehouse & BI* (Superset, Hop),
  *Code quality* (Semgrep), *Realtime* (Centrifugo, EMQX), plus Kafka UI — masing
  -masing dengan titik ●/○ status keterjangkauan.
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

- **Buka di `http://localhost:4423`** — **bukan** `drawdb.test`.
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
  `configs/hop/jdbc-drivers/` — lihat README di sana untuk mengambil ulang jar
  (`HOP_MYSQL_DRIVER` di `.env`). Postgres tak butuh apa-apa; Kafka pakai
  *transforms* bawaan Hop (bukan JDBC); MongoDB/Redis tak punya driver JDBC.
- **Tanpa timeout sesi.** Hop Web (Eclipse RAP) mengikat kanvas ke sesi HTTP;
  kami ubah timeout default 30 menit Tomcat menjadi *tak pernah* agar Anda tak
  kena "session timed out" di tengah kerja (wrapper `command` pada service).
- **Persistensi:** proyek/konfigurasi berada **di dalam** container
  (`/usr/local/tomcat/webapps/ROOT/...`) dan hilang saat container dibuat ulang;
  proyek bawaan `default` dan `samples` selalu ada.

### Apache Superset — `superset.test`

**Dashboard & pelaporan BI.** Login **`admin` / `admin`**.

- **Image:** Docker Hardened Image `${DHI_REGISTRY}/superset` — varian runtime
  non-dev, nonroot (UID 65532).
- **Inisialisasi sendiri saat start** (db upgrade → buat admin → init → gunicorn),
  dijalankan dari Python venv image karena image hardened tak punya shell.
- **Metadata** berupa SQLite di volume `superset-home` — cukup untuk dev. Jika
  Anda membuatnya ulang dari volume pra-DHI (UID 1000) dan boot gagal dengan
  *"attempt to write a readonly database"*, kepemilikan volume usang; reset
  (`docker volume rm local-dev-stack_superset-home`) atau `chown` ke `65532`.

## Code quality — Semgrep

**Profile:** `semgrep` (`LDS_ENABLE_SEMGREP`). **Mati secara default.**

Pemindai analisis statis (SAST) dengan viewer SARIF yang ringan. Terdiri dari
dua service compose:

- **`semgrep`** (profile `semgrep`, `all`) — **viewer**: nginx kecil yang
  menyajikan `configs/semgrep/reports/` di `semgrep.test`. Inilah yang dijalankan
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
```

Itu menjalankan image `semgrep-scan` yang dipin dengan `docker run -v <path>:/src`
dan menulis `configs/semgrep/reports/report.sarif` ke folder yang disajikan
viewer. (Memakai `docker run`, bukan `docker compose run`, karena parser `-v`
Compose memecah pada `:` dan gagal pada path drive Windows seperti `D:\…`.)
Segarkan **`semgrep.test`** dan viewer menampilkan temuan (filter per severity /
cari). Tanpa DB; sebelum Anda menjalankan scan, belum ada `report.sarif`.

Ruleset default **`p/default`**, dijalankan dengan telemetri **off**. Pilih lain
via `SEMGREP_RULES` — pack registry mana pun (`p/php`, `p/security-audit`,
`p/ci`), URL rules, atau YAML lokal; semua jalan dengan metrics off. `auto` juga
valid tapi **wajib metrics on** (mengunggah metadata proyek ke semgrep.dev untuk
memilih rules), dan unggahan akhir itu bisa menggantung pada koneksi
lambat/offline — jadi skrip hanya menyalakan metrics bila Anda set
`SEMGREP_RULES=auto`. (Pack registry tetap diambil via jaringan saat scan mulai;
itu waktu muat, bukan macet.)

---

Lihat [12 · Port](12-ports.md) untuk peta port host dan
[13 · Profile](13-profiles.md) untuk setiap profile secara rinci.
