# 12 · Port

Semua port host berada di blok **`44xx`** agar tidak bentrok dengan apa pun di
mesin Anda. Masing-masing diatur oleh variabel `*_HOST_PORT` di `.env`.

|        Grup        |      Layanan       |           Host + Port           |  Dari Container + Port  |
|--------------------|--------------------|---------------------------------|-------------------------|
| **Data** `440x` ------------------------------------------------------------------------------------|
|                    | MySQL              | `localhost:4400`                | `mysql:3306`            |
|                    | PostgreSQL         | `localhost:4401`                | `postgres:5432`         |
|                    | MongoDB            | `localhost:4402`                | `mongo:27017`           |
|                    | Redis              | `localhost:4403`                | `redis:6379`            |
|                    | Memcached          | `localhost:4404`                | `memcached:11211`       |
| **Kafka** `441x` -----------------------------------------------------------------------------------|
|                    | Broker (bootstrap) | `localhost:4410`                | `kafka-broker:9092`     |
|                    | Schema Registry    | `localhost:4411`                | `schema-registry:8080`  |
|                    | Connect — generic  | `localhost:4412`                | `connect-generic:8083`  |
|                    | Connect — Debezium | `localhost:4413`                | `connect-debezium:8083` |
| **UI Web** `442x+` ---------------------------------------------------------------------------------|
|                    | Kafka UI           | `localhost:4420`                | `kafka-ui:8080`         |
|                    | phpCacheAdmin      | `localhost:4421` (`cache.test`) | `phpcacheadmin:80`      |
|                    | DBGate             | `localhost:4422` (`db.test`)    | `dbgate:3000`           |
|                    | DrawDB             | `localhost:4423` (buka di sini, **bukan** `drawdb.test`) | `drawdb:80` |
|                    | Apache Hop         | `localhost:4424` (`hop.test`)   | `hop:8080`              |
|                    | Apache Superset    | `localhost:4425` (`superset.test`) | `superset:8088`      |
|                    | Viewer Semgrep     | `localhost:4426` (`semgrep.test`) | `semgrep:80`          |
|                    | InsightTrack UI    | `localhost:4427` (`insighttrack.test`) | `insighttrack:4173` |
|                    | InsightTrack API   | `localhost:4428`                | `insighttrack-backend:3001` |
|                    | Vaultwarden        | `localhost:4429` (`vaultwarden.test`) | `vaultwarden:80`    |
|                    | Werkyn             | `localhost:4435` (`werkyn.test`) | `werkyn:3000`          |
| **Realtime** `443x` --------------------------------------------------------------------------------|
|                    | Soketi (Pusher)    | `localhost:4430` (`ws.test`)    | `soketi:6001`           |
|                    | Centrifugo + UI    | `localhost:4431` (`centrifugo.test`) | `centrifugo:8000`  |
|                    | Mosquitto — MQTT   | `localhost:4432`                | `mosquitto:1883`        |
|                    | Mosquitto — MQTT/WS | `localhost:4433` (path `/`)     | `mosquitto:9001`        |
|                    | MQTTX web client   | `localhost:4434` (`mqtt.test`)  | `mqttx:80`              |
| **Infra** ------------------------------------------------------------------------------------------|
|                    | Proxy web          | `localhost:80` (`*.test`)       |            —            |
|                    | Proxy web (HTTPS)  | `localhost:443` (`*.test`, opt-in) |         —            |
|                    | DNS                | `localhost:53` (udp + tcp)      |            —            |

- **Dari host**, hubungkan ke `localhost:<port>` (kolom kiri).
- **Dari container lain** di `lds-network`, pakai nama layanan + port
  internalnya (kolom kanan) — ini tidak berubah saat Anda me-remap port host.
- **Infra tetap:** proxy web tetap `80` (URL `http://app.test` bersih tanpa
  suffix port) dan DNS tetap `53` (resolver OS menanyakan port 53 untuk
  me-resolve `*.test`).
- **Panel kontrol:** `http://localhost` (dilayani container php, rute default
  proxy) menampilkan semua tool + proyek — lihat [15 · Dashboard & data tools](15-data-tools.md).
- **Pengecualian DrawDB:** buka di `localhost:4423`, **bukan** `drawdb.test` via
  http — butuh secure context (`localhost` atau HTTPS) untuk `crypto.randomUUID`.
- **HTTPS opt-in:** port `443` (`WEB_HTTPS_PORT`) hanya dipublikasikan saat
  `LDS_ENABLE_HTTPS=true`. Jalankan `lds certs` sekali untuk membuat cert dev
  wildcard `*.test` — lihat [13 · Profile](13-profiles.md) → *TLS / sertifikat*.
- Untuk mengubah port host, edit `*_HOST_PORT` di `.env` (mis.
  `MYSQL_HOST_PORT=4400`), lalu buat ulang container: `lds down && lds up`.
