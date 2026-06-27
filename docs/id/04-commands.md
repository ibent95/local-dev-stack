# 04 · Perintah (wrapper `lds`)

`lds` adalah satu entrypoint yang meneruskan ke skrip di `scripts/`. Pakai
`./lds.sh <cmd>` (bash) atau `lds.bat <cmd>` (Windows cmd).

| Perintah | Fungsi |
|----------|--------|
| `init` | buat jaringan bersama `lds-network` (sekali saja) |
| `network [status\|create\|rm\|reset]` | kelola jaringan bersama `lds-network` (status = tampilkan + container terpasang) |
| `build-bases [--force\|--push]` | build base image `lds/*` |
| `up [profiles...]` | jalankan profile (tanpa argumen → profile yang toggle `LDS_ENABLE_*`-nya `true`, selain itu `all`); auto-build `lds/php` bila perlu |
| `stop` | hentikan container tapi **tetap simpan** (lanjut cepat via `up`; data tak tersentuh) |
| `down [-v]` | hapus container (`-v` juga hapus volume data) |
| `logs [service]` | pantau log (semua, atau satu service) |
| `ps` | status semua service |
| `kafka <sub>` | `topics` · `connect-plugin [--generic] <name>` · `register-connectors` · `init` (topik + connector) |
| `db <sub>` | `init [mysql\|mongo\|all]` (buat db/user `app`) · `seed` (koneksi DBGate) |
| `tools <sub>` | `semgrep [path]` — jalankan scan Semgrep; lihat di `semgrep.test` (`up semgrep`) |
| `certs [--force]` | buat cert TLS dev wildcard `*.test` (untuk overlay `LDS_ENABLE_HTTPS`) |
| `hosts-sync` | tulis proyek + host tool ke berkas hosts (fallback DNS), dikelompokkan per kategori |
| `build-php [--push]` | build ulang image service PHP saja |
| `help` | daftar perintah |

> Subperintah berkelompok ini menggantikan nama datar lama, yang **tetap bekerja
> sebagai alias**: `kafka-topics`, `register-connectors`, `connect-plugin`,
> `mysql-init`, `mongo-init`, `dbgate-seed`.

Tiap skrip juga ada mandiri di `scripts/run/` dan `scripts/build/`, dalam
bentuk `.sh` dan `.bat`.

## Alur kerja harian

- Jalankan yang dibutuhkan: `./lds.sh up mysql redis`
- Log: `./lds.sh logs kafka-broker` · Status: `./lds.sh ps`
- Hentikan: `./lds.sh down` (data tetap) atau `./lds.sh down -v` (hapus data)
- Setelah bump versi/dep: `./lds.sh build-bases --force`
