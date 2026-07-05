# 04 · Perintah (wrapper `lds`)

`lds` adalah satu entrypoint yang meneruskan ke skrip di `scripts/`. Pakai
`./lds.sh <cmd>` (bash) atau `lds.bat <cmd>` (Windows cmd).

<table>
<thead>
<tr>
<th>Perintah</th>
<th>Fungsi</th>
</tr>
</thead>
<tbody>
<tr>
<td>`init`</td>
<td>buat jaringan bersama `lds-network` (sekali saja)</td>
</tr>
<tr>
<td>`network [status\|create\|rm\|reset]`</td>
<td>kelola jaringan bersama `lds-network` (status = tampilkan + container terpasang)</td>
</tr>
<tr>
<td>`build-bases [--force\|--push]`</td>
<td>build base image `lds/*`</td>
</tr>
<tr>
<td>`up [profiles...]`</td>
<td>jalankan profile (tanpa argumen → profile yang toggle `LDS_ENABLE_*`-nya `true`, selain itu `all`); auto-build `lds/php` bila perlu</td>
</tr>
<tr>
<td>`stop`</td>
<td>hentikan container tapi **tetap simpan** (lanjut cepat via `up`; data tak tersentuh)</td>
</tr>
<tr>
<td>`down [-v]`</td>
<td>hapus container (`-v` juga hapus volume data)</td>
</tr>
<tr>
<td>`logs [service]`</td>
<td>pantau log (semua, atau satu service)</td>
</tr>
<tr>
<td>`ps`</td>
<td>status semua service</td>
</tr>
<tr>
<td>`kafka &lt;sub&gt;`</td>
<td>`topics` · `connect-plugin [--generic] &lt;name&gt;` · `register-connectors` · `init` (topik + connector)</td>
</tr>
<tr>
<td>`db &lt;sub&gt;`</td>
<td>`init [mysql\|mongo\|all]` (buat db/user `app`) · `seed` (koneksi DBGate)</td>
</tr>
<tr>
<td>`tools &lt;sub&gt;`</td>
<td>`semgrep [path]` — jalankan scan Semgrep; lihat di `semgrep.test` (`up semgrep`)</td>
</tr>
<tr>
<td>`certs [--force]`</td>
<td>buat cert TLS dev wildcard `*.test` (untuk overlay `LDS_ENABLE_HTTPS`)</td>
</tr>
<tr>
<td>`hosts-sync`</td>
<td>tulis proyek + host tool ke berkas hosts (fallback DNS), dikelompokkan per kategori</td>
</tr>
<tr>
<td>`build-php [--push]`</td>
<td>build ulang image service PHP saja</td>
</tr>
<tr>
<td>`help`</td>
<td>daftar perintah</td>
</tr>
</tbody>
</table>

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
