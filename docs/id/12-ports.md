# 12 · Port

Semua port host berada di blok **`44xx`–`45xx`** agar tidak bentrok dengan apa pun
di mesin Anda. Masing-masing diatur oleh variabel `*_HOST_PORT` di `.env`.

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
<td>MariaDB</td>
<td><code>localhost:4406</code></td>
<td><code>mariadb:3306</code></td>
</tr>
<tr>
<td></td>
<td>SQL Server 2025 (Developer)</td>
<td><code>localhost:4407</code></td>
<td><code>mssql:1433</code></td>
</tr>
<tr>
<td></td>
<td>Oracle Database Free (23ai)</td>
<td><code>localhost:4408</code> (EM Express: <code>localhost:4409/em</code>)</td>
<td><code>oracle:1521</code></td>
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
<td>Valkey</td>
<td><code>localhost:4405</code></td>
<td><code>valkey:6379</code></td>
</tr>
<tr>
<td></td>
<td>Memcached</td>
<td><code>localhost:4404</code></td>
<td><code>memcached:11211</code></td>
</tr>
<tr>
<td></td>
<td>RabbitMQ (AMQP)</td>
<td><code>localhost:4410</code></td>
<td><code>rabbitmq:5672</code></td>
</tr>
<tr>
<td></td>
<td>RabbitMQ (UI manajemen)</td>
<td><code>localhost:4411</code></td>
<td><code>rabbitmq:15672</code></td>
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
    <b>Realtime</b> <code>4440–4449</code>
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
    <b>Mesin query analitis</b> <code>4450–4459</code>
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
    <b>Alat admin</b> <code>4500–4543</code>
</td>
</tr>
<tr>
<td></td>
<td>phpCacheAdmin</td>
<td><code>localhost:4500</code> (<code>cache.test</code>)</td>
<td><code>phpcacheadmin:80</code></td>
</tr>
<tr>
<td></td>
<td>DBX</td>
<td><code>localhost:4501</code> (<code>db.test</code>)</td>
<td><code>dbx:4224</code></td>
</tr>
<tr>
<td></td>
<td>DrawDB</td>
<td><code>localhost:4502</code> (buka di sini, <b>bukan</b> <code>drawdb.test</code>)</td>
<td><code>drawdb:80</code></td>
</tr>
<tr>
<td></td>
<td>Apache Hop</td>
<td><code>localhost:4503</code> (<code>hop.test</code>)</td>
<td><code>hop:8080</code></td>
</tr>
<tr>
<td></td>
<td>Apache Superset</td>
<td><code>localhost:4504</code> (<code>superset.test</code>)</td>
<td><code>superset:8088</code></td>
</tr>
<tr>
<td></td>
<td>Metabase</td>
<td><code>localhost:4541</code> (<code>metabase.test</code>)</td>
<td><code>metabase:3000</code></td>
</tr>
<tr>
<td></td>
<td>Hoppscotch</td>
<td><code>localhost:4542</code> (<code>hoppscotch.test</code>)</td>
<td><code>hoppscotch:80</code></td>
</tr>
<tr>
<td></td>
<td>Plane</td>
<td><code>localhost:4543</code> (<code>plane.test</code>)</td>
<td><code>plane-proxy:80</code></td>
<tr>
<td></td>
<td>Viewer Semgrep</td>
<td><code>localhost:4505</code> (<code>semgrep.test</code>)</td>
<td><code>semgrep:8080</code></td>
</tr>
<tr>
<td></td>
<td>OWASP ZAP — UI</td>
<td><code>localhost:4510</code> (<code>zap.test</code>)</td>
<td><code>zap:8080</code></td>
</tr>
<tr>
<td></td>
<td>OWASP ZAP — proxy/API</td>
<td><code>localhost:4512</code></td>
<td><code>zap:8090</code></td>
</tr>
<tr>
<td></td>
<td>Viewer Trivy</td>
<td><code>localhost:4511</code> (<code>trivy.test</code>)</td>
<td><code>trivy:8080</code></td>
</tr>
<tr>
<td></td>
<td>Mailpit — inbox web</td>
<td><code>localhost:4513</code> (<code>mail.test</code>)</td>
<td><code>mailpit:8025</code></td>
</tr>
<tr>
<td></td>
<td>Mailpit — SMTP</td>
<td><code>localhost:4514</code></td>
<td><code>mailpit:1025</code></td>
</tr>
<tr>
<td></td>
<td>Vaultwarden</td>
<td><code>localhost:4506</code> (<code>vaultwarden.test</code>)</td>
<td><code>vaultwarden:80</code></td>
</tr>
<tr>
<td></td>
<td>Penpot</td>
<td><code>localhost:4518</code> (<code>penpot.test</code>)</td>
<td><code>penpot-frontend:8080</code></td>
</tr>
<tr>
<td></td>
<td>OpenWA</td>
<td><code>localhost:4507</code> (<code>openwa.test</code>)</td>
<td><code>openwa:2785</code></td>
</tr>
<tr>
<td></td>
<td>RustFS — API</td>
<td><code>localhost:4508</code></td>
<td><code>rustfs:9000</code></td>
</tr>
<tr>
<td></td>
<td>RustFS — Console</td>
<td><code>localhost:4509</code> (<code>rustfs.test</code>)</td>
<td><code>rustfs:9001</code></td>
</tr>
<tr>
<td></td>
<td>HeadlessX — dashboard web</td>
<td><code>localhost:4515</code> (<code>headlessx.test</code>)</td>
<td><code>headlessx-web:3000</code></td>
</tr>
<tr>
<td></td>
<td>HeadlessX — API / MCP</td>
<td><code>localhost:4516</code> (<code>headlessx-api.test</code>)</td>
<td><code>headlessx-api:8000</code></td>
</tr>
<tr>
<td></td>
<td>HeadlessX — sidecar HTML→MD</td>
<td><code>localhost:4517</code></td>
<td><code>headlessx-html-to-md:8080</code></td>
</tr>
<tr>
<td></td>
<td>HeadlessX — YT engine</td>
<td><code>localhost:4519</code></td>
<td><code>headlessx-yt-engine:8090</code></td>
</tr>
<tr>
<td></td>
<td>Playwright — viewer laporan</td>
<td><code>localhost:4526</code> (<code>playwright.test</code>)</td>
<td><code>playwright-report:8080</code></td>
</tr>
<tr>
<td></td>
<td>Playwright — UI Mode</td>
<td><code>localhost:4527</code> (buka via `lds playwright ui &lt;nama&gt;`)</td>
<td><code>playwright:8787</code></td>
</tr>
<tr>
<td></td>
<td>Instatic — visual CMS</td>
<td><code>localhost:4528</code> (<code>instatic.test</code>, admin di <code>/admin</code>)</td>
<td><code>instatic:3001</code></td>
</tr>
<tr>
<td></td>
<td>ERPNext — frontend</td>
<td><code>localhost:4529</code> (<code>erpnext.test</code>)</td>
<td><code>erpnext-frontend:8080</code></td>
</tr>
<tr>
<td></td>
<td>Viewer code-review-graph</td>
<td><code>localhost:4530</code> (<code>crg.test</code>)</td>
<td><code>crg:8080</code></td>
</tr>
<tr>
<td></td>
<td>Grafana</td>
<td><code>localhost:4532</code> (<code>grafana.test</code>)</td>
<td><code>grafana:3000</code></td>
</tr>
<tr>
<td></td>
<td>Prometheus</td>
<td><code>localhost:4533</code> (<code>prometheus.test</code>)</td>
<td><code>prometheus:9090</code></td>
</tr>
<tr>
<td></td>
<td>draw.io</td>
<td><code>localhost:4535</code> (<code>drawio.test</code>)</td>
<td><code>drawio:8080</code></td>
</tr>
<tr>
<td></td>
<td>LLDAP — LDAP</td>
<td><code>localhost:4537</code></td>
<td><code>lldap:3890</code></td>
</tr>
<tr>
<td></td>
<td>OpenLDAP — LDAP</td>
<td><code>localhost:4540</code></td>
<td><code>openldap:389</code></td>
</tr>
<tr>
<td></td>
<td>SnapOtter</td>
<td><code>localhost:4538</code> (<code>snapotter.test</code>)</td>
<td><code>snapotter:1349</code></td>
</tr>
<tr>
<td></td>
<td>ImgCompress</td>
<td><code>localhost:4539</code> (<code>imgcompress.test</code>)</td>
<td><code>imgcompress:5000</code></td>
</tr>
<tr>
<td colspan="4">
    <b>Aplikasi LDS</b> <code>4520–4525</code>
</td>
</tr>
<tr>
<td></td>
<td>LDS Analytics &mdash; API</td>
<td><code>localhost:4520</code></td>
<td><code>analytics-api:3001</code></td>
</tr>
<tr>
<td></td>
<td>LDS Analytics &mdash; UI</td>
<td><code>localhost:4521</code> (<code>lds-analytics.test</code>)</td>
<td><code>analytics-ui:4173</code></td>
</tr>
<tr>
<td></td>
<td>LDS Tasks &mdash; API</td>
<td><code>localhost:4522</code></td>
<td><code>tasks-api:3002</code></td>
</tr>
<tr>
<td></td>
<td>LDS Tasks &mdash; UI</td>
<td><code>localhost:4523</code> (<code>lds-tasks.test</code>)</td>
<td><code>tasks-ui:4174</code></td>
</tr>
<tr>
<td></td>
<td>LDS Wiki &mdash; API</td>
<td><code>localhost:4524</code></td>
<td><code>wiki-api:3003</code></td>
</tr>
<tr>
<td></td>
<td>LDS Wiki &mdash; UI</td>
<td><code>localhost:4525</code> (<code>lds-wiki.test</code>)</td>
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
- **Pengecualian DrawDB:** buka di `localhost:4502`, **bukan** `drawdb.test` via
  http — butuh secure context (`localhost` atau HTTPS) untuk `crypto.randomUUID`.
- **HTTPS opt-in:** port `443` (`WEB_HTTPS_PORT`) hanya dipublikasikan saat
  `LDS_ENABLE_HTTPS=true`. Jalankan `lds certs` sekali untuk membuat cert dev
  wildcard `*.test` — lihat [13 · Profile](13-profiles.md) → *TLS / sertifikat*.
- Untuk mengubah port host, edit `*_HOST_PORT` di `.env` (mis.
  `MYSQL_HOST_PORT=4400`), lalu buat ulang container: `lds down && lds up`.
