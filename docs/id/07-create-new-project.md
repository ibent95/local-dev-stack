# 07 · Membuat proyek baru dari template

Membuat proyek baru = **salin template, ganti nama, jalankan**. Anda tidak
pernah mengubah berkas milik `local-dev-stack`.

1. **Salin** template ke mana saja (di dalam `templates/` atau folder bahasa Anda):
   ```bash
   cp -r templates/svc-template-go  D:/projects/Golang/orders
   ```
2. **Beri nama** — set `APP_HOST` di `.env` di samping berkas compose, mis.
   `APP_HOST=orders.test`.
3. **Jalankan:** `docker compose up -d` → `http://orders.test`.

**Tidak perlu halaman `public/`/index.** Itu hanya untuk berkas PHP biasa di
`www/` (mass-vhost bersama). Template menjalankan server-nya sendiri dan cukup
mendengarkan di `VIRTUAL_PORT`-nya.

**Tidak perlu registrasi di LDS.** Anda TIDAK menambah apa pun ke
`docker-compose.yml` milik LDS. Hostname baru otomatis bekerja: `dns` me-resolve
`*.test` secara **wildcard** dan `proxy` **menemukan otomatis** container yang
men-set `VIRTUAL_HOST`.

**Prasyarat tetap** (sekali set): `./lds.sh init` + DNS adapter → `127.0.0.1`;
biarkan `./lds.sh up proxy` berjalan. Template sudah gabung `lds-network` dan set
`VIRTUAL_HOST`.

> Tidak ingin ubah DNS sistem? `lds hosts-sync` (admin/sudo) menulis entri hosts
> per-proyek — tapi jalankan ulang tiap proyek baru (tanpa wildcard).
