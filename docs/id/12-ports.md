# 12 · Port

Semua port host berada di blok **`44xx`** agar tidak bentrok dengan apa pun di
mesin Anda. Masing-masing diatur oleh variabel `*_HOST_PORT` di `.env`.

<table>
<thead>
<tr>
<th>Grup</th>
<th>Layanan</th>
<th>Host + Port</th>
<th>Dari Container + Port</th>
</tr>
</thead>
<tbody>
<tr>
<td colspan="4">
    <b>Database</b> <code>4400–4419</code>
</td>
</tr>
<tr>
<td></td>
<td>MySQL</td>
<td><code>localhost:4400</code></td>
<td><code>mysql:3306</code></td>
</tr>
<tr>
<td></td>
<td>PostgreSQL</td>
<td><code>localhost:4401</code></td>
<td><code>postgres:5432</code></td>
</tr>
<tr>
<td></td>
<td>MongoDB</td>
<td><code>localhost:4402</code></td>
<td><code>mongo:27017</code></td>
</tr>
<tr>
<td></td>
<td>Redis</td>
<td><code>localhost:4403</code></td>
<td><code>redis:6379</code></td>
</tr>
<tr>
<td></td>
<td>Memcached</td>
<td><code>localhost:4404</code></td>
<td><code>memcached:11211</code></td>
</tr>
<tr>
<td colspan="4">
    <b>Kafka</b> <code>4420–4439</code>
</td>
</tr>
<tr>
<td></td>
<td>Broker (bootstrap)</td>
<td><code>localhost:4420</code></td>
<td><code>kafka-broker:9092</code></td>
</tr>
<tr>
<td></td>
<td>Schema Registry</td>
<td><code>localhost:4421</code></td>
<td><code>schema-registry:8080</code></td>
</tr>
<tr>
<td></td>
<td>Connect — generic</td>
<td><code>localhost:4422</code></td>
<td><code>connect-generic:8083</code></td>
</tr>
<tr>
<td></td>
<td>Connect — Debezium</td>
<td><code>localhost:4423</code></td>
<td><code>connect-debezium:8083</code></td>
</tr>
<tr>
<td></td>
<td>Kafka UI</td>
<td><code>localhost:4424</code></td>
<td><code>kafka-ui:8080</code></td>
</tr>
<tr>
<td colspan="4">
    <b>Realtime</b> <code>4440–4459</code>
</td>
</tr>
<tr>
<td></td>
<td>Soketi (Pusher)</td>
<td><code>localhost:4440</code> (<code>ws.test</code>)</td>
<td><code>soketi:6001</code></td>
</tr>
<tr>
<td></td>
<td>Centrifugo + UI</td>
<td><code>localhost:4441</code> (<code>centrifugo.test</code>)</td>
<td><code>centrifugo:8000</code></td>
</tr>
<tr>
<td></td>
<td>Mosquitto — MQTT</td>
<td><code>localhost:4442</code></td>
<td><code>mosquitto:1883</code></td>
</tr>
<tr>
<td></td>
<td>Mosquitto — MQTT/WS</td>
<td><code>localhost:4443</code> (path <code>/</code>)</td>
<td><code>mosquitto:9001</code></td>
</tr>
<tr>
<td></td>
<td>MQTTX web client</td>
<td><code>localhost:4444</code> (<code>mqtt.test</code>)</td>
<td><code>mqttx:80</code></td>
</tr>
<tr>
<td colspan="4">
    <b>Mesin query analitis</b> <code>4451–4459</code>
</td>
</tr>
<tr>
<td></td>
<td>DuckDB</td>
<td><code>n/a</code> (file engine)</td>
<td><code>n/a</code> (embedded)</td>
</tr>
<tr>
<td></td>
<td>Trino</td>
<td><code>localhost:4451</code> (<code>/ui</code>)</td>
<td><code>trino:8080</code></td>
</tr>
<tr>
<td colspan="4">
    <b>Alat admin</b> <code>4460–4479</code>
</td>
</tr>
<tr>
<td></td>
<td>phpCacheAdmin</td>
<td><code>localhost:4460</code> (<code>cache.test</code>)</td>
<td><code>phpcacheadmin:80</code></td>
</tr>
<tr>
<td></td>
<td>DBGate</td>
<td><code>localhost:4461</code> (<code>db.test</code>)</td>
<td><code>dbgate:3000</code></td>
</tr>
<tr>
<td></td>
<td>DrawDB</td>
<td><code>localhost:4462</code> (buka di sini, <b>bukan</b> <code>drawdb.test</code>)</td>
<td><code>drawdb:80</code></td>
</tr>
<tr>
<td></td>
<td>Apache Hop</td>
<td><code>localhost:4463</code> (<code>hop.test</code>)</td>
<td><code>hop:8080</code></td>
</tr>
<tr>
<td></td>
<td>Apache Superset</td>
<td><code>localhost:4464</code> (<code>superset.test</code>)</td>
<td><code>superset:8088</code></td>
</tr>
<tr>
<td></td>
<td>Viewer Semgrep</td>
<td><code>localhost:4465</code> (<code>semgrep.test</code>)</td>
<td><code>semgrep:80</code></td>
</tr>
<tr>
<td></td>
<td>Vaultwarden</td>
<td><code>localhost:4466</code> (<code>vaultwarden.test</code>)</td>
<td><code>vaultwarden:80</code></td>
</tr>
<tr>
<td></td>
<td>OpenWA</td>
<td><code>localhost:4467</code> (<code>openwa.test</code>)</td>
<td><code>openwa:8080</code></td>
</tr>
<tr>
<td></td>
<td>RustFS — API</td>
<td><code>localhost:4468</code></td>
<td><code>rustfs:9000</code></td>
</tr>
<tr>
<td></td>
<td>RustFS — Console</td>
<td><code>localhost:4469</code> (<code>rustfs.test</code>)</td>
<td><code>rustfs:9001</code></td>
</tr>
<tr>
<td colspan="4">
    <b>Aplikasi LDS</b> <code>4480–4499</code>
</td>
</tr>
<tr>
<td></td>
<td>Analytics API</td>
<td><code>localhost:4480</code></td>
<td><code>analytics-api:3001</code></td>
</tr>
<tr>
<td></td>
<td>Analytics UI</td>
<td><code>localhost:4481</code> (<code>analytics.test</code>)</td>
<td><code>analytics-ui:4173</code></td>
</tr>
<tr>
<td></td>
<td>Tasks API</td>
<td><code>localhost:4482</code></td>
<td><code>tasks-api:3002</code></td>
</tr>
<tr>
<td></td>
<td>Tasks UI</td>
<td><code>localhost:4483</code> (<code>tasks.test</code>)</td>
<td><code>tasks-ui:4174</code></td>
</tr>
<tr>
<td></td>
<td>Wiki API</td>
<td><code>localhost:4484</code></td>
<td><code>wiki-api:3003</code></td>
</tr>
<tr>
<td></td>
<td>Wiki UI</td>
<td><code>localhost:4485</code> (<code>wiki.test</code>)</td>
<td><code>wiki-ui:4175</code></td>
</tr>
<tr>
<td colspan="4">
    <b>Infra</b>
</td>
</tr>
<tr>
<td></td>
<td>Proxy web</td>
<td><code>localhost:80</code> (<code>*.test</code>)</td>
<td>—</td>
</tr>
<tr>
<td></td>
<td>Proxy web (HTTPS)</td>
<td><code>localhost:443</code> (<code>*.test</code>, opt-in)</td>
<td>—</td>
</tr>
<tr>
<td></td>
<td>DNS</td>
<td><code>localhost:53</code> (udp + tcp)</td>
<td>—</td>
</tr>
</tbody>
</table>

- **Dari host**, hubungkan ke `localhost:<port>` (kolom kiri).
- **Dari container lain** di `lds-network`, pakai nama layanan + port
  internalnya (kolom kanan) — ini tidak berubah saat Anda me-remap port host.
- **Infra tetap:** proxy web tetap `80` (URL `http://app.test` bersih tanpa
  suffix port) dan DNS tetap `53` (resolver OS menanyakan port 53 untuk
  me-resolve `*.test`).
- **Panel kontrol:** `http://localhost` (dilayani container php, rute default
  proxy) menampilkan semua tool + proyek — lihat [15 · Dashboard & data tools](15-data-tools.md).
- **Pengecualian DrawDB:** buka di `localhost:4462`, **bukan** `drawdb.test` via
  http — butuh secure context (`localhost` atau HTTPS) untuk `crypto.randomUUID`.
- **HTTPS opt-in:** port `443` (`WEB_HTTPS_PORT`) hanya dipublikasikan saat
  `LDS_ENABLE_HTTPS=true`. Jalankan `lds certs` sekali untuk membuat cert dev
  wildcard `*.test` — lihat [13 · Profile](13-profiles.md) → *TLS / sertifikat*.
- Untuk mengubah port host, edit `*_HOST_PORT` di `.env` (mis.
  `MYSQL_HOST_PORT=4400`), lalu buat ulang container: `lds down && lds up`.
