# 11 · Pekerjaan terjadwal (cron)

LDS menjalankan tugas terjadwal dengan **[supercronic](https://github.com/aptible/supercronic)** —
cron yang ramah-kontainer: berjalan sebagai non-root, membaca `crontab` standar,
dan mencatat setiap eksekusi ke **stdout** (jadi `docker logs` / `lds app logs`
langsung menampilkannya). Ia satu proses foreground, jadi **tidak** butuh daemon
`cron` sistem maupun `supervisord` hanya untuk menjadwalkan.

Ada **dua cara** menjadwalkan, tergantung apakah job berdiri sendiri atau bagian
dari aplikasi PHP.

---

## A. Cron job mandiri — teknologi apa pun (disarankan)

Kontainer khusus untuk satu tugas terjadwal. Cocok untuk **bahasa apa pun** —
job hanyalah perintah yang dijalankan supercronic sesuai jadwal.

```bash
lds new cron-python my-job   # atau cron-shell / cron-node / cron-go / cron-php
cd <folder tsb>
lds app start                # build & jalankan
lds app logs                 # pantau tiap eksekusi
lds app stop
```

`cron` adalah role kelas-satu (seperti `svc`/`web`): `lds new cron-<tech> <name>`
men-scaffold `cron-template-<tech>` ke `*_PROJECTS_PATH` tech tsb (jadi
`cron-python` masuk ke `PYTHON_PROJECTS_PATH` bersama proyek Python lainnya;
`cron-shell`, yang tanpa rumah bahasa, memakai `JOBS_PROJECTS_PATH`). Tiap
template berisi:
- **`crontab`** — jadwalnya, mis. `*/5 * * * * <jalankan job>`
- **`job.<ext>`** — tugas dalam bahasa tsb (ubah ini)
- **`Dockerfile`** — base bahasa + supercronic (Go build biner dulu)
- **`docker-compose.yml`** — gabung `lds-network`, **tanpa port web** (worker)

Karena di `lds-network`, job menjangkau layanan backing lewat nama:
`mysql:3306`, `postgres:5432`, `mongo:27017`, `redis:6379`, `kafka-broker:9092`.

### Tech cron yang tersedia (dan cara tiap-tiap dijalankan)
Pilih role-tech; template menyiapkan base image + perintah crontab untukmu:

| Bahasa | Base Dockerfile | baris crontab |
|---|---|---|
| Shell | `alpine` (default) | `*/5 * * * * /app/job.sh` |
| Python | `python:3.12-slim` | `*/5 * * * * python /app/job.py` |
| Node | `node:22-alpine` | `*/5 * * * * node /app/job.js` |
| PHP | `php:8.4-cli` | `*/5 * * * * php /app/job.php` |
| Go (compiled) | multi-stage → binary di `alpine` | `*/5 * * * * /app/job` |

Runtime interpreted (Python/Node/PHP) cukup menjalankan skrip. Yang compiled
(Go/Rust/Java) di-build dulu jadi artefak, lalu supercronic menjalankan binernya
(supaya tidak dikompilasi ulang tiap tick).

> **Contoh nyata:** `svc-setting-access-log-retention-python` — purge native-Python
> yang menghapus baris `access_log` lebih lama dari `RETENTION_DAYS` via PyMySQL,
> dijadwalkan supercronic.

### Dua image: lokal vs cloud (deploy)
Tiap proyek cron punya **dua Dockerfile**:
- **`Dockerfile`** — image **cloud/default** (yang dibuild Kubernetes/Fleet).
  Mandiri: `COPY` source + biner supercronic yang di-vendor.
- **`LDS.Dockerfile`** — image **lokal** untuk `lds`/docker-compose
  (`build.dockerfile: LDS.Dockerfile`); bind-mount source untuk live edit. Ia
  mengambil supercronic dari base `lds/*` (semua base kini menyertakannya), jadi
  **tidak** mem-vendor biner — kecuali `cron-shell` (base Alpine, tak punya).

**Tanpa jaringan saat build:** supercronic **di-vendor untuk image cloud** —
`lds new cron-*` menyalin `assets/supersonic/<ver>/supercronic-linux-amd64` ke
proyek sebagai `bin/supercronic`, dan `Dockerfile` cloud `COPY` biner itu (base
resmi-nya tak punya supercronic). Jadi build cloud jalan offline / di balik
firewall (commit `bin/supercronic` ke repo).

---

## B. Di dalam kontainer aplikasi PHP

Base `lds/php` menyertakan supercronic sebagai program supervisord, **mati secara
default**. Aktifkan per proyek:

1. Sediakan crontab di `/etc/supervisor/crontab` (COPY di Dockerfile proyek, atau mount).
2. Set `ENABLE_CRON=true` di environment service.

supervisord lalu menjalankannya bersama php-fpm + nginx. Kontainer `php`
mass-vhost bersama membiarkannya mati.

**Laravel / Symfony** tetap memakai program scheduler **sendiri** (mis. `worker.conf`
Laravel dengan `[program:scheduler]`, di-toggle `ENABLE_SCHEDULER`), bukan
`[program:cron]` generik.

---

## Base image lain (Go / Rust / Node / Python / Java)

Base dev tersebut menjalankan **satu** proses foreground (air, watchfiles, …) —
**tidak** menyertakan supervisord/supercronic. Untuk tugas terjadwal di stack
itu, pakai **cara A** (kontainer cron mandiri). Satu job = satu kontainer lebih
bersih, terisolasi, dan mirip Kubernetes CronJob.

---

## Rujukan singkat crontab

```
# ┌ menit (0-59)
# │ ┌ jam (0-23)
# │ │ ┌ tanggal (1-31)
# │ │ │ ┌ bulan (1-12)
# │ │ │ │ ┌ hari (0-6, Min=0)
# │ │ │ │ │
  * * * * *  perintah
```
Contoh: `*/5 * * * *` tiap 5 menit · `0 2 * * *` harian 02:00 · `0 * * * *` tiap jam.
Waktu memakai `TZ` kontainer. supercronic mencatat tiap eksekusi; crontab salah
membuatnya keluar non-zero (fail-fast).
