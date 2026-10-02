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
<td>`init [mysql\|postgres\|mongo\|all]` (buat db/user default + spec tool opsional via `*_INIT_SPECS`) · `seed` (koneksi DBX)</td>
</tr>
<tr>
<td>`tools &lt;sub&gt;`</td>
<td>`semgrep [path\|clear]` — jalankan/hapus report Semgrep · `trivy [path\|clear]` / `trivy image &lt;name&gt;` — jalankan/hapus report Trivy · `crg &lt;path&gt; [name]` — bangun code-review-graph + ekspor; lihat di `semgrep.test` / `trivy.test` / `crg.test` · `playwright &lt;…&gt;` — alias untuk `lds playwright` (lihat di bawah)</td>
</tr>
<tr>
<td>`playwright &lt;sub&gt;`</td>
<td>`init &lt;name&gt; [url]` — scaffold proyek E2E · `run &lt;name&gt; [args…]` — jalankan tes · `codegen [url]` — rekam tes · `ui &lt;name&gt;` — UI Mode interaktif di browser (:4527) · `shell` — shell runner · `report` — URL viewer (`playwright.test` / :4526); alias: `e2e`</td>
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
<td>`env-sync [--dry-run]`</td>
<td>sinkronkan `.env` ke `.env.example` — nilai Anda dipertahankan, variabel yang hilang ditambahkan di posisi contoh, variabel khusus `.env` dipertahankan (auto-run oleh `up`)</td>
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
> `mysql-init`, `mongo-init`, `dbx-seed`.

Tiap skrip juga ada mandiri di `scripts/run/` dan `scripts/build/`, dalam
bentuk `.sh` dan `.bat`.

## Alur kerja harian

- Jalankan yang dibutuhkan: `./lds.sh up mysql redis`
- Log: `./lds.sh logs kafka-broker` · Status: `./lds.sh ps`
- Hentikan: `./lds.sh down` (data tetap) atau `./lds.sh down -v` (hapus data)
- Setelah bump versi/dep: `./lds.sh build-bases --force`
