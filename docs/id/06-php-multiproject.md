# 06 · Hosting proyek PHP (`www/`)

Profile `php` otomatis meng-host setiap folder di dalam `www/` (gaya Devilbox):

```
www/myshop/public/index.php → http://myshop.test
```

- Docroot dideteksi otomatis per proyek: `public/` → `htdocs/` → root folder.
- Tanpa konfigurasi atau build ulang saat menambah proyek — taruh folder lalu refresh.
- Agar `*.test` ter-resolve, set DNS adapter ke `127.0.0.1` (atau pakai
  `lds hosts-sync`) — lihat [14 · DNS](14-dns.md).
- Untuk meng-host proyek yang sudah ada: set `PHP_PROJECTS_PATH` di `.env` ke
  folder induk (mis. `PHP_PROJECTS_PATH=D:/projects/PHP`). Default-nya `./www`,
  folder contoh bawaan LDS.

Ini mode **mass-vhost bersama** (PHP biasa, berbasis berkas). Untuk proyek
ter-container bahasa apa pun, gunakan template — lihat [07](07-create-new-project.md).
