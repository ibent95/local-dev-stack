# 05 · Base image

Set ekstensi PHP dan tooling dev tiap bahasa dibangun **sekali** menjadi base
image bersama `lds/*` (sumber di `base-images/`), lalu dipakai ulang oleh stack
dan tiap template — sehingga instalasi berat (PECL, cargo-watch, …) hanya sekali.

Semua base dibangun **FROM Docker Hardened Images (DHI)** di bawah
`${DHI_REGISTRY:-dhi.io}`, memakai flavor `-dev` (menyertakan shell + apt). DHI
default ke user non-root, jadi tiap Dockerfile memakai `USER root` untuk langkah
build + runtime-nya.

<table>
<thead>
<tr>
<th>Image</th>
<th>FROM (DHI)</th>
<th>Isi</th>
</tr>
</thead>
<tbody>
<tr>
<td>`lds/php`</td>
<td>`alpine-base:3.24-dev` ¹</td>
<td>php-fpm + ekstensi + composer **+ nginx + supervisor**, membakar global `configs/php-app/*` (satu-satunya base PHP; supervisord menjalankan php-fpm + nginx)</td>
</tr>
<tr>
<td>`lds/go-dev`</td>
<td>`golang:1.26-alpine3.24-dev`</td>
<td>Go + air</td>
</tr>
<tr>
<td>`lds/rust-dev`</td>
<td>`rust:1.96-alpine3.24-dev`</td>
<td>Rust + cargo-watch</td>
</tr>
<tr>
<td>`lds/node-dev`</td>
<td>`node:26.3-alpine3.24-dev`</td>
<td>Node terpinned</td>
</tr>
<tr>
<td>`lds/python-dev`</td>
<td>`python:3.14-alpine3.24-dev`</td>
<td>Python + watchfiles</td>
</tr>
<tr>
<td>`lds/java-dev`</td>
<td>`eclipse-temurin:25-jdk-alpine3.24-dev` ²</td>
<td>Maven + JDK</td>
</tr>
</tbody>
</table>

¹ **PHP adalah pengecualian DHI.** Image `dhi.io/php` terpisah — build `-dev`
minimal **tanpa php-fpm** dan **tanpa helper `docker-php-ext-*`**, plus runtime
`-fpm` ter-harden **tanpa shell/apk** — sehingga keduanya tak bisa menampung
kontainer gemuk tunggal. Maka `lds/php` dibangun FROM
`dhi.io/alpine-base:3.24-dev` dan memasang php-fpm + ekstensi + nginx +
supervisor dari repo Alpine (`php` = `php84`). Repo DHI Alpine tak punya php,
jadi Dockerfile menambah repo upstream Alpine `main`+`community` (bentuk sama
seperti debian-base menarik php dari Debian). `rdkafka`, `redis`, dan
`memcached` tersedia sebagai paket apk (`php84-pecl-*`, yang otomatis meng-enable
ini conf.d-nya); `apfd` (tanpa paket apk) dikompilasi via **PECL** memakai
toolchain `.build-deps` sekali-pakai yang di-`apk del` setelahnya, sehingga image
final tak membawa compiler. `apk` Alpine tak punya mesin init/postinst, jadi tak ada masalah daemon-postinst
`adm`/`www-data`/`invoke-rc.d` yang harus diakali di Debian. Shim kompatibilitas
menjaga layout official-image yang dibutuhkan config/mount: `php-fpm84` (+
`php84`/`phpize84`/`php-config84`) di `$PATH`, pool fpm di `127.0.0.1:9000`
sebagai user `nginx`, `/usr/local/etc/php/conf.d` di-symlink ke
`/etc/php84/conf.d`, dan `conf.d` nginx di-symlink ke `http.d` (Alpine
meng-include blok `server{}` dari `http.d`, bukan `conf.d`).

² DHI tak menerbitkan image `maven:*`, jadi `java-dev` memasang Apache Maven dari
dist biner `archive.apache.org` — `wget` busybox Alpine + `tar` yang sadar-gzip
mengunduh & mengekstraknya, jadi tak perlu apk install.

> **Catatan musl:** semua base bahasa memakai flavor Alpine (musl) agar satu
> keluarga OS di seluruh stack. Konsekuensi: wheel Python dan native addon Node
> harus punya build musl, jika tidak akan dikompilasi dari source di template.

- Versi digerakkan env (`PHP_VERSION`, `GO_VERSION`, … di `.env`); tiap `FROM`
  Dockerfile membawa suffix OS/flavor per bahasa. Set `DHI_REGISTRY` di `.env`
  untuk mengarahkan ulang namespace DHI.
- Build / refresh: `./lds.sh build-bases` (`--force` rebuild, `--push` ke `$REGISTRY`).
  Diorkestrasi oleh `docker-bake.hcl` (`docker buildx bake`) — keenam dibangun paralel.
- Dibangun **sekali**; rebuild hanya saat versi/dependensi berubah — bukan tiap
  build template, bukan tiap ubah kode.
- Stage **dev** template `FROM lds/*`; stage **prod** tetap pakai image publik
  yang ramping.

> Service DB (`mysql`/`postgres`/`redis`/`memcached`) dan image dns juga berasal
> dari DHI — lihat [13 · Profiles](13-profiles.md). Service DB memakai flavor
> **runtime** ter-harden biasa (tanpa `-dev`): `postgres`/`redis` di
> `*-alpine3.24`, `mysql`/`memcached` di `*-debian13` (DHI tak punya varian
> Alpine untuk keduanya). Image dns dibangun FROM `dhi.io/alpine-base:3.24-dev`.
