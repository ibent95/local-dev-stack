# 01 · Ikhtisar

Satu stack Docker Compose yang menyediakan layanan pendukung yang dibutuhkan
proyek Anda saat pengembangan — MySQL, PostgreSQL, Redis, Memcached, runtime
PHP, dan stack Kafka lengkap (dengan Debezium CDC). Tiap kelompok berada di
balik **profile**, jadi Anda hanya menjalankan yang diperlukan.

Di atas layanan tersebut, **proxy** edge (nginx-proxy) + **dnsmasq** memberi
tiap proyek hostname `<nama>.test`, dan pustaka **template** men-scaffold proyek
baru untuk berbagai bahasa dan framework.

- Profile: `proxy`, `php`, `mysql`, `postgres`, `mongo`, `redis`, `memcached`,
  `kafka`, `phpcacheadmin`, `dbgate`, `soketi`, `centrifugo`, `emqx`, `all`. Tiap
  profile dijelaskan rinci di [13 · Profile](13-profiles.md).
- `lds up` tanpa profile menjalankan setiap profile yang toggle
  `LDS_ENABLE_<PROFILE>`-nya di `.env` bernilai `true` (default: `proxy`, `php`,
  `mysql`, `dbgate` aktif). Ubah satu baris (mis. `LDS_ENABLE_KAFKA=true`) untuk menambah
  grup. Broker realtime (`soketi`, `centrifugo`, `emqx`) mati secara default —
  jalankan salah satu dengan `lds up <nama>` atau ubah toggle-nya.
- Semua berbagi satu jaringan eksternal, `lds-network`.
- Satu perintah wrapper, `lds`, menjalankan seluruh stack (lihat [04](04-commands.md)).
