# 16 · Berkontribusi

LDS adalah infrastruktur bersama: satu stack Compose, skrip shell `lds`,
dashboard PHP, dan handbook dua bahasa. Perubahan di sini merambat ke semua
proyek yang berjalan di atas stack, jadi kontribusi mengikuti daftar periksa
singkat yang eksplisit. Versi lengkap panduan ini ada di root repositori
[`CONTRIBUTING.md`](https://github.com/ibent95/local-dev-stack/blob/master/CONTRIBUTING.md)
— bab ini adalah ringkasannya.

## Cara berkontribusi

- **Bug** → formulir issue bug report.
- **Fitur / service baru / template** → buka issue dulu, sepakati bentuknya,
  baru PR-nya.
- **Keamanan** → jangan pernah lewat issue publik; lihat
  [17 · Keamanan](17-security.md).
- **Dokumentasi** → setiap bab ada dalam bahasa Inggris **dan** Indonesia;
  jaga pasangannya tetap sinkron.
- **Kode** → fork, branch dari `master`, buka PR ke `master`.

## Persiapan dev

Prasyarat: Docker (Desktop atau Engine) dengan Compose v2, Git, dan Bash (Git
Bash di Windows).

```bash
git clone https://github.com/<kamu>/local-dev-stack.git
cd local-dev-stack
cp .env.example .env        # di-git-ignore - jangan pernah di-commit
./lds.sh init               # network + setup awal
./lds.sh build-bases        # build base image lds/* (sekali saja)
./lds.sh up                 # run-set bawaan dari toggle di .env kamu
```

Di Windows gunakan `lds.bat` (dari `cmd`) atau skrip `.sh` lewat Git Bash.

## Aturan sinkronisasi

Sebagian besar perubahan menyentuh banyak berkas **secara sengaja**:

- **Profile/service baru** → `docker-compose.yml` **dan** daftar profil di
  `scripts/run/up.sh` + `scripts/run/up.bat` **dan** toggle
  `LDS_ENABLE_<PROFILE>` di `.env.example`.
- **Env var baru** → tambahkan ke `.env.example` (urutan/komentar ikut dari
  sana); `lds env-sync --dry-run` harus bersih. `up` menjalankan `env-sync`
  diam-diam, jadi var yang hilang tetap akan ditulis ulang.
- **Skrip berpasangan** — setiap `.sh` butuh kembaran `.bat` (hanya
  `env-sync` yang juga punya `.ps1`). Berkas shell harus tetap **LF**:
  `.gitattributes` memaksa ini karena `sh`/`ash` gagal menerima CRLF.
- **Service/alat baru** → baris di [18 · Kredit](18-credits.md), sebutan di
  [15 · Tool data](15-data-tools.md) bila itu alat, dan kartu di dashboard
  (`configs/web/dashboard/index.php`).
- **Bab docs baru** → di `docs/en/` **dan** `docs/id/`, nomor bebas
  berikutnya, dan entri bernomor di **kedua** indeks `README.md`.
- **PHP dashboard** → `docker exec lds-php php -l <file>`, lalu
  `docker restart lds-php` (opcache `revalidate_freq=300`).
- **Mengganti TLD dev** → ubah `configs/nginx/default.conf` **dan**
  `configs/dns/dnsmasq.conf` bersamaan.

Konvensi: container bernama `lds-*`; nilai Compose memakai
`${VAR:-default}`; antar-service berbicara lewat nama di `lds-network`
(bukan port host); jangan bergantung pada `COMPOSE_PROFILES` (toggle dibaca
langsung sehingga `lds up <profile>` tetap terarah). Referensi arsitektur
lebih lengkap ada di `.github/copilot-instructions.md` dan `CLAUDE.md`.

## Validasi sebelum PR

**Tidak ada runner unit test** di root — validasi adalah kebenaran Compose,
kesehatan container, dan scanner bawaan:

```bash
docker compose config --quiet       # sintaks/interpolasi compose
./lds.sh ps                         # sehat setelah up
./lds.sh env-sync --dry-run         # selisih .env vs .env.example
./lds.sh tools semgrep ./scripts    # SAST (viewer di semgrep.test)
./lds.sh tools trivy .              # CVE/SCA (viewer di trivy.test)
```

Untuk docs, buka bab yang disentuh di **kedua** bahasa dan periksa sidebar,
TOC, serta tautan prev/next.

## Daftar periksa PR

- [ ] Compose valid (`docker compose config --quiet`)
- [ ] Profile/toggle tersinkron di `up.sh`, `up.bat`, `.env.example`
- [ ] Perubahan shell ada di `.sh` **dan** `.bat`, LF terjaga
- [ ] Docs EN + ID, indeks README bernomor, baris kredit ditambahkan
- [ ] PHP dashboard di-lint dan `lds-php` di-restart
- [ ] Tidak ada rahasia yang di-stage (`.env`, `configs/proxy/certs/*`,
      `data/*`, `*.db` semuanya di-git-ignore)
- [ ] PR menjelaskan apa yang berubah, mengapa, dan cara mengujinya

## Gaya commit & PR

Pesan singkat dan imperatif; repo ini secara historis memakai prefiks
`Updated:` (mis. `Updated: swap DBGate for DBX`). Jaga PR tetap fokus — satu
service atau tool per PR.

## Lisensi

Kontribusi didistribusikan di bawah [lisensi MIT](https://github.com/ibent95/local-dev-stack/blob/master/LICENSE)
repositori ini.
