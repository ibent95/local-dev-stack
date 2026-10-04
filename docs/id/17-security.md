# 17 · Keamanan

Postur keamanan Local Dev Stack: cara melaporkan masalah, apa yang **tidak**
dilindungi stack secara bawaan (ini lingkungan dev localhost), dan apa yang
perlu dijalankan sebelum mengirim perubahan. Kebijakan lengkapnya ada di root
repositori [`SECURITY.md`](https://github.com/ibent95/local-dev-stack/blob/master/SECURITY.md).

## Melaporkan kerentanan

Gunakan **private vulnerability reporting GitHub**, jangan pernah issue
publik:

**Report a vulnerability** →
<https://github.com/ibent95/local-dev-stack/security/advisories/new>

Sertakan bagian yang terdampak (service compose, skrip, dashboard, docs),
langkah reproduksi, dampak, dan saran perbaikan. Kamu akan menerima
konfirmasi dan penilaian awal; tanggal disclosure disepakati per laporan.
Pengujian beritikad baik (jalankan lokal, pakai scanner bawaan, telaah kode)
dilarang merusak data atau menyerang layanan yang bukan milikmu.

**Cakupan**: berkas compose, skrip, Dockerfile, configs, dan PHP dashboard
repositori ini. Kerentanan di proyek upstream (Kafka, Superset, Penpot, …)
juga harus dilaporkan ke upstream — kita mengejar perbaikannya dengan menaikkan
pin di `.env.example` / `docker-compose.yml`.

**Versi yang didukung**: hanya `master`. Tidak ada cabang rilis; perbarui
checkout kamu sebelum melapor.

## Default khusus dev (tidak dihardening secara sengaja)

Semua di bawah ini adalah perilaku **localhost-only yang disengaja** —
didokumentasikan agar tidak disalahartikan sebagai postur produksi, dan agar
kamu tahu apa yang harus diubah lebih dulu jika stack keluar dari mesinmu:

<table>
<thead><tr><th>Default</th><th>Di mana</th><th>Cara mengeras</th></tr></thead>
<tbody>
<tr><td>Password DB <code>root</code> / <code>app</code> (MySQL, MariaDB, Mongo, Postgres)</td><td><code>docker-compose.yml</code> + <code>.env.example</code></td><td>isi <code>MYSQL_ROOT_PASSWORD</code>, <code>POSTGRES_PASSWORD</code>, <code>MONGO_*</code> di <code>.env</code>, lalu <code>./lds.sh down -v</code> untuk membuat ulang volume</td></tr>
<tr><td>SQL Server <code>Lds-dev-2024!</code>, Oracle <code>Oracle-dev-2024!</code></td><td>sama</td><td><code>MSSQL_SA_PASSWORD</code>, <code>ORACLE_PASSWORD</code></td></tr>
<tr><td>Superset <code>admin</code>/<code>admin</code> + secret key <code>…change-me</code></td><td>sama</td><td><code>SUPERSET_ADMIN</code>, <code>SUPERSET_PASSWORD</code>, <code>SUPERSET_SECRET_KEY</code></td></tr>
<tr><td>UI DBX <b>tanpa password</b> (<code>DBX_DISABLE_PASSWORD=1</code>)</td><td>sama</td><td><code>DBX_DISABLE_PASSWORD=0</code> + <code>DBX_PASSWORD</code></td></tr>
<tr><td>Secret Vaultwarden / Penpot / Instatic / RustFS / OpenWA semuanya <code>…change-me</code></td><td>sama</td><td>isi masing-masing <code>*_SECRET_KEY</code>, <code>*_TOKEN</code>, <code>*_KEY</code> di <code>.env</code></td></tr>
<tr><td>Centrifugo + Soketi berjalan dalam mode dev <code>*_insecure</code></td><td>sama</td><td>key nyata; hilangkan <code>--client_insecure</code> / <code>--admin_insecure</code></td></tr>
<tr><td>Dashboard dan viewer Semgrep/Trivy/CRG/ZAP <b>tanpa login</b></td><td>dashboard + compose</td><td>biarkan lokal, atau pasang auth di proxy</td></tr>
<tr><td>Port host dipublikasikan ke semua antarmuka (default Docker)</td><td>compose <code>ports:</code></td><td>ikat ke loopback: <code>"127.0.0.1:4405:6379"</code></td></tr>
<tr><td>Hanya HTTP (tanpa TLS)</td><td>proxy</td><td><code>LDS_ENABLE_HTTPS=true</code> + <code>./lds.sh certs</code></td></tr>
<tr><td><code>*.test</code> mengarah ke <code>127.0.0.1</code></td><td><code>configs/dns</code></td><td>biarkan lokal; jangan mendelegasikan zona ke publik</td></tr>
</tbody>
</table>

## Tooling bawaan

```bash
./lds.sh tools semgrep [path]     # SAST - viewer SARIF di semgrep.test
./lds.sh tools trivy [path]       # CVE/SCA atas berkas, dependensi, image
./lds.sh tools trivy image <name> # sama, untuk satu image
./lds.sh up zap                   # DAST terhadap aplikasi berjalan (zap.test)
./lds.sh tools crg <path>         # graf intelejen kode AI (crg.test)
```

Perintah ini juga menjadi scan yang disarankan sebelum PR (lihat
[16 · Berkontribusi](16-contributing.md)).

## Rantai pasok & kebersihan rahasia

- `.env` **di-git-ignore**; `.env.example` berisi default dev terdokumentasi
  tanpa rahasia nyata. `configs/proxy/certs/` diabaikan oleh `.gitignore`
  miliknya sendiri; `data/*/*` dan `*.db` juga diabaikan.
- Jar driver JDBC **tidak pernah di-commit** (pembatasan redistribusi) — tiap
  developer mengunduhnya sendiri mengikuti `assets/jdbc/README.md`.
- Image service dan base memakai **Docker Hardened Images** (`dhi.io`);
  komponen pihak ketiga beserta lisensinya tercantum di
  [18 · Kredit](18-credits.md).
- Versi dikunci di `.env.example`; Dependabot
  ([`.github/dependabot.yml`](https://github.com/ibent95/local-dev-stack/blob/master/.github/dependabot.yml))
  membuka PR bulanan untuk image Compose dengan tag literal, GitHub Actions,
  serta manifest desktop/aplikasi stack.
- Pohon repositori digrep untuk kunci privat dan token API sebelum rilis;
  jika menemukannya, laporkan secara pribadi (anggap saja sudah terkompromi).
