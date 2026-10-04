# 18 · Credits & Third-Party Software

Local Dev Stack is an assembler, not an inventor: nearly everything it runs is
someone else's work. This chapter credits every library, app, container image
and system tool the stack hosts or uses - what it is, the version we pin, and
the license it carries.

Three notes before the tables:

- **Version** = the default baked into `.env.example` / `docker-compose.yml`
  (`${VAR:-default}`). Override it in `.env` and recreate the service. A tag
  shown without a variable is hard-coded in a compose file or a Dockerfile.
- **License** = the license of the project or image as published upstream.
  A couple of entries are proprietary (SQL Server, Oracle) - those are free for
  local development under the publisher's own terms, nothing more.
- Almost no third-party code lives in this repo itself. The few files we vendor
  (last table) keep their own license texts. When you add a service to
  `docker-compose.yml`, give it a row here.

## Base images & language runtimes

<table>
<thead><tr><th>Project</th><th>What it does in LDS</th><th>Version (env)</th><th>License</th></tr></thead>
<tbody>
<tr><td><a href="https://dhi.io/">Docker Hardened Images (DHI)</a></td><td>Hardened minimal bases under <code>${DHI_REGISTRY}</code> - every service image and every <code>lds/*</code> base builds <code>FROM</code> them</td><td><code>DHI_REGISTRY</code> = <code>dhi.io</code></td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td>Alpine Linux</td><td>Distro behind the language dev bases (the DHI <code>golang</code>/<code>node</code>/<code>python</code>/<code>rust</code>/<code>eclipse-temurin</code> <code>-alpine3.24-dev</code> images) and the <code>dns</code> image</td><td>3.24</td><td>Mixed (per package)</td></tr>
<tr><td>Debian</td><td>Distro behind <code>lds/php</code>, <code>lds/duckdev</code> and the CRG scanner (<code>python:3.12-slim</code>)</td><td>13 (trixie)</td><td><a href="https://www.debian.org/legal/">Mixed (per package)</a></td></tr>
<tr><td><code>lds/php</code></td><td>The one PHP base, on Debian 13: php-fpm + nginx + composer + supervisor + supercronic (built from this repo)</td><td><code>PHP_VERSION</code> = 8.4</td><td><a href="https://www.php.net/license/3_01.txt">PHP-3.01</a> (the runtime)</td></tr>
<tr><td><a href="https://getcomposer.org/">Composer</a></td><td>Copied into <code>lds/php</code> from the official image so PHP templates can resolve dependencies</td><td><code>composer:2</code> (floating tag)</td><td><a href="https://opensource.org/license/mit">MIT</a></td></tr>
<tr><td><code>lds/go-dev</code></td><td>Go toolchain + <a href="https://github.com/air-verse/air">air</a> live-reload for the <code>go</code> templates</td><td><code>GO_VERSION</code> = 1.26</td><td><a href="https://go.dev/LICENSE">BSD-3-Clause</a> (Go); air <a href="https://opensource.org/license/mit">MIT</a></td></tr>
<tr><td><code>lds/rust-dev</code></td><td>Rust toolchain + cargo-watch, rustup and the Tauri CLI for <code>rust</code>/<code>tauri</code> templates</td><td><code>RUST_VERSION</code> = 1.96</td><td><a href="https://opensource.org/license/mit">MIT</a> <b>OR</b> <a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><code>lds/node-dev</code></td><td>Node.js toolchain for the <code>node</code>/<code>express</code>/SPA templates and the analytics, tasks and wiki APIs</td><td><code>NODE_VERSION</code> = 26.3</td><td><a href="https://github.com/nodejs/node/blob/main/LICENSE">MIT (Node.js)</a></td></tr>
<tr><td><code>lds/python-dev</code></td><td>Python toolchain + watchfiles for the <code>python</code>/<code>flask</code>/<code>fastapi</code>/<code>django</code> templates</td><td><code>PYTHON_VERSION</code> = 3.14</td><td><a href="https://docs.python.org/3/license.html">PSF-2.0</a>; watchfiles <a href="https://opensource.org/license/mit">MIT</a></td></tr>
<tr><td><code>lds/java-dev</code></td><td>Eclipse Temurin JDK + Apache Maven for the Java, Spring, Micronaut, Quarkus and Vaadin templates</td><td><code>JAVA_VERSION</code> = 25</td><td><a href="https://openjdk.org/legal/gplv2+ce.html">GPL-2.0 WITH Classpath-exception</a>; Maven <a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><code>lds/javafx-dev</code></td><td>OpenJFX on top of <code>lds/java-dev</code> for JavaFX desktop templates</td><td>from <code>JAVA_VERSION</code></td><td><a href="https://openjdk.org/legal/gplv2+ce.html">GPL-2.0 WITH Classpath-exception</a></td></tr>
<tr><td><code>lds/nativephp-dev</code></td><td>NativePHP toolchain on top of <code>lds/php</code> for native desktop/mobile apps written in PHP</td><td>from <code>PHP_VERSION</code></td><td><a href="https://github.com/NativePHP/desktop/blob/main/LICENSE.md">MIT</a></td></tr>
<tr><td><code>lds/tauri-dev</code> / <code>tauri-win-dev</code></td><td>Rust to native desktop bases for the Tauri templates</td><td>from <code>RUST_VERSION</code></td><td><a href="https://github.com/tauri-apps/tauri/blob/dev/LICENSE_APACHE">Apache-2.0</a> (runtime); MIT/Apache-2.0 (CLI)</td></tr>
<tr><td><code>lds/duckdev</code></td><td>Base for the DuckDB helper image, bundling the DuckDB CLI</td><td><code>DUCKDB_VERSION</code> = 1.2.0</td><td><a href="https://github.com/duckdb/duckdb/blob/main/LICENSE">MIT</a></td></tr>
</tbody>
</table>

## Web edge, DNS & TLS

<table>
<thead><tr><th>Project</th><th>What it does in LDS</th><th>Version (env)</th><th>License</th></tr></thead>
<tbody>
<tr><td><a href="https://github.com/nginx-proxy/nginx-proxy">nginx-proxy</a></td><td>The front door: one nginx that routes every <code>&lt;folder&gt;.test</code> and tool hostname to its container via <code>VIRTUAL_HOST</code></td><td>1.6</td><td><a href="https://opensource.org/license/mit">MIT</a></td></tr>
<tr><td>nginx (<code>lds/nginx</code>)</td><td>Pinned nginx runtime reused by the stack's own viewer and UI containers (Semgrep, Trivy and CRG report viewers, tasks/wiki UIs). The mass-virtual-host nginx that serves every <code>.test</code> docroot is baked into <code>lds/php</code></td><td><code>NGINX_VERSION</code> = 1.27</td><td><a href="https://nginx.org/en/LICENSE.html">BSD-2-Clause</a></td></tr>
<tr><td>dnsmasq</td><td>Answers <code>*.test</code> with 127.0.0.1 for the host, and with the proxy IP for ZAP inside the network</td><td>from the <code>dns</code> image</td><td><a href="https://www.gnu.org/licenses/old-licenses/gpl-2.0.html">GPL-2.0</a></td></tr>
</tbody>
</table>

## Databases

<table>
<thead><tr><th>Project</th><th>What it does in LDS</th><th>Version (env)</th><th>License</th></tr></thead>
<tbody>
<tr><td>MySQL</td><td>Shared SQL database, CDC-ready (binlog + GTID) for Debezium</td><td><code>MYSQL_VERSION</code> = 8.4-debian13</td><td><a href="https://www.mysql.com/about/legal/licensing/">GPL-2.0 + FOSS exception</a></td></tr>
<tr><td>MariaDB</td><td>Drop-in alternative SQL database (<code>LDS_ENABLE_MARIADB</code>)</td><td><code>MARIADB_VERSION</code> = 11.8-debian13</td><td><a href="https://mariadb.com/about/license/">GPL-2.0</a></td></tr>
<tr><td>SQL Server (Developer)</td><td>Full-featured free edition for development and testing</td><td><code>MSSQL_VERSION</code> = 2025-latest</td><td><a href="https://www.microsoft.com/licensing/terms/product/formentities/SQLServer">Proprietary EULA</a> (free for dev/test)</td></tr>
<tr><td>Oracle Database Free</td><td>via the <a href="https://github.com/gvenzl/oci-oracle-free">gvenzl/oracle-free</a> mirror image, no Oracle account needed</td><td><code>ORACLE_VERSION</code> = 23.26.2-slim</td><td>image <a href="https://github.com/gvenzl/oci-oracle-free/blob/main/LICENSE">Apache-2.0</a>; database <a href="https://www.oracle.com/downloads/licenses/technology-license.html">Oracle Free Use Terms</a></td></tr>
<tr><td>PostgreSQL</td><td>Shared SQL database, CDC-ready (logical WAL); also hosts ERPNext</td><td><code>POSTGRES_VERSION</code> = 18.4-alpine3.24</td><td><a href="https://www.postgresql.org/about/licence/">PostgreSQL License</a></td></tr>
<tr><td>MongoDB</td><td>Document database on a single-node replica set (<code>rs0</code>) with auth, CDC-ready</td><td><code>MONGO_VERSION</code> = 8.3-debian13-dev</td><td><a href="https://www.mongodb.com/licensing/server-side-public-license">SSPL-1.0</a></td></tr>
<tr><td>Redis</td><td>Cache, queue and broker for jobs and frameworks (Laravel, ERPNext, Superset)</td><td><code>REDIS_VERSION</code> = 8.8-alpine3.24</td><td><a href="https://redis.io/legal/open-source-notice/">RSALv2 / SSPL (your choice)</a></td></tr>
<tr><td>Valkey</td><td>Redis-compatible drop-in alternative (<code>LDS_ENABLE_VALKEY</code>)</td><td><code>VALKEY_VERSION</code> = 8.1-alpine</td><td><a href="https://opensource.org/license/bsd-3-clause">BSD-3-Clause</a></td></tr>
<tr><td>Memcached</td><td>Memory cache, also browsable through phpCacheAdmin</td><td><code>MEMCACHED_VERSION</code> = 1.6-debian13</td><td><a href="https://opensource.org/license/bsd-3-clause">BSD-3-Clause</a></td></tr>
<tr><td><a href="https://github.com/t8y2/dbx">DBX</a></td><td>Web client for 100+ databases, pre-seeded with the stack's own databases (<code>db.test</code>)</td><td><code>DBX_VERSION</code> = 0.6.31</td><td><a href="https://github.com/t8y2/dbx/blob/main/LICENSE">Apache-2.0</a></td></tr>
<tr><td><a href="https://github.com/RobiNN1/phpCacheAdmin">phpCacheAdmin</a></td><td>GUI for Redis, Valkey, Memcached, OPcache and APCu (<code>cache.test</code>)</td><td><code>PHPCACHEADMIN_VERSION</code> = 2.5.2</td><td><a href="https://github.com/RobiNN1/phpCacheAdmin/blob/master/LICENSE">MIT</a></td></tr>
</tbody>
</table>

## Streaming (Kafka & realtime)

<table>
<thead><tr><th>Project</th><th>What it does in LDS</th><th>Version (env)</th><th>License</th></tr></thead>
<tbody>
<tr><td>Apache Kafka</td><td>KRaft broker + dedicated controller running every CDC and messaging workload</td><td><code>KAFKA_VERSION</code> = 4.3-debian13</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td>Kafka Connect</td><td>The connector runtime that ships with Kafka, used for CDC and generic sinks</td><td>with <code>KAFKA_VERSION</code></td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://debezium.io/">Debezium</a></td><td>CDC connectors (MySQL, Postgres, MongoDB to Kafka) on the dedicated worker, REST on <code>:4423</code></td><td><code>DEBEZIUM_VERSION</code> = 3.0</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://apicurio.io/">Apicurio Registry</a></td><td>In-memory schema registry; Avro values through the Apicurio Connect converter</td><td><code>APICURIO_VERSION</code> = 2.6.13.Final</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://kafbat.io/">Kafbat kafka-ui</a></td><td>Browser UI for topics, connectors and schemas (<code>kafka.test</code>, ccompat on <code>/apis/ccompat/v7</code>)</td><td><code>KAFKA_UI_VERSION</code> = v1.5.0</td><td><a href="https://github.com/kafbat/kafka-ui/blob/main/LICENSE">Apache-2.0</a></td></tr>
<tr><td>Generic Connect worker</td><td>The DHI Kafka image run as a second Connect worker; plugins added with <code>lds connect-plugin</code></td><td>with <code>KAFKA_VERSION</code></td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://github.com/eclipse/mosquitto">Eclipse Mosquitto</a></td><td>MQTT broker with native (<code>:4442</code>) and WebSocket (<code>:4443</code>) listeners</td><td><code>MOSQUITTO_VERSION</code> = 2.0.22</td><td><a href="https://www.eclipse.org/legal/epl-2.0/">EPL-2.0</a> / <a href="https://spdx.org/licenses/EDL-1.0.html">EDL-1.0</a></td></tr>
<tr><td><a href="https://mqttx.app/">MQTTX Web</a></td><td>Browser MQTT client for poking the broker (<code>mqtt.test</code>)</td><td><code>MQTTX_VERSION</code> = v1.13.0</td><td><a href="https://github.com/emqx/MQTTX/blob/main/LICENSE">Apache-2.0</a></td></tr>
<tr><td><a href="https://github.com/soketi/soketi">Soketi</a></td><td>Pusher-protocol WebSocket server for Laravel Reverb/Echo and pusher-js clients</td><td><code>SOKETI_VERSION</code> = 1.6-16-alpine</td><td><a href="https://github.com/soketi/soketi/blob/1.x/LICENSE">AGPL-3.0</a></td></tr>
<tr><td><a href="https://centrifugal.github.io/centrifugo/">Centrifugo</a></td><td>Raw WebSocket channels with an admin UI (<code>centrifugo.test</code>), runs in dev insecure mode</td><td><code>CENTRIFUGO_VERSION</code> = v5</td><td><a href="https://github.com/centrifugal/centrifugo/blob/master/LICENSE">Apache-2.0</a></td></tr>
</tbody>
</table>

## Data, ETL & BI

<table>
<thead><tr><th>Project</th><th>What it does in LDS</th><th>Version (env)</th><th>License</th></tr></thead>
<tbody>
<tr><td><a href="https://hop.apache.org/">Apache Hop</a></td><td>Visual ETL designer and server (<code>hop.test</code>), projects auto-registered from <code>HOP_PROJECTS_PATH</code></td><td><code>HOP_VERSION</code> = 2.18.1</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://superset.apache.org/">Apache Superset</a></td><td>BI dashboards (<code>superset.test</code>), SQLite metadata on disk</td><td><code>SUPERSET_VERSION</code> = 6.1-debian13</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://github.com/drawdb-io/drawdb">DrawDB</a></td><td>Browser ER/schema designer, opened on <code>localhost:4502</code> (needs a secure context)</td><td><code>DRAWDB_VERSION</code> = v1.7.0</td><td><a href="https://github.com/drawdb-io/drawdb/blob/main/LICENSE">AGPL-3.0</a></td></tr>
<tr><td><a href="https://duckdb.org/">DuckDB</a></td><td>Embedded OLAP engine; the CLI is vendored and used by local helper scripts</td><td><code>DUCKDB_VERSION</code> = 1.2.0</td><td><a href="https://github.com/duckdb/duckdb/blob/main/LICENSE">MIT</a></td></tr>
<tr><td><a href="https://trino.io/">Trino</a></td><td>Federated SQL engine (<code>trino.test</code>) for querying several databases at once</td><td><code>TRINO_VERSION</code> = latest</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://hive.apache.org/">Apache Hive</a></td><td>Hive metastore and SQL engine, wired to Trino and the shared Postgres</td><td>hive:4.0.0 (hard-coded)</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td>pandas + PyArrow</td><td>Installed by <code>scripts/run/seed-data.sh</code> to generate sample datasets</td><td>host <code>pip</code> (unpinned)</td><td><a href="https://opensource.org/license/bsd-3-clause">BSD-3-Clause</a> + <a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td>JDBC drivers</td><td>Six drivers single-file-mounted into Hop and the Hive metastore, downloaded per developer (git-ignored)</td><td>pinned per jar</td><td>Mixed - MySQL <a href="https://www.gnu.org/licenses/old-licenses/gpl-2.0.html">GPL-2.0</a>, MariaDB <a href="https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html">LGPL-2.1</a>, Oracle <a href="https://www.oracle.com/downloads/licenses/technology-license.html">Free Use Terms</a>, mssql <a href="https://opensource.org/license/mit">MIT</a>, PostgreSQL <a href="https://opensource.org/license/bsd-2-clause">BSD-2-Clause</a>, Trino <a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a> (see <code>assets/jdbc/README.md</code>)</td></tr>
</tbody>
</table>

## Apps & platforms

<table>
<thead><tr><th>Project</th><th>What it does in LDS</th><th>Version (env)</th><th>License</th></tr></thead>
<tbody>
<tr><td><a href="https://penpot.app/">Penpot</a></td><td>Open-source design and prototyping tool (frontend, backend and exporter containers)</td><td><code>PENPOT_VERSION</code> = 2.17.0</td><td><a href="https://github.com/penpot/penpot/blob/develop/LICENSE">MPL-2.0</a></td></tr>
<tr><td><a href="https://erpnext.com/">ERPNext</a> (Frappe)</td><td>Full ERP suite - about eight services plus two bootstrap jobs, on shared Postgres/MariaDB and Redis</td><td><code>ERPNEXT_VERSION</code> = 16.31.1</td><td><a href="https://www.gnu.org/licenses/gpl-3.0.en.html">GPL-3.0</a></td></tr>
<tr><td><a href="https://github.com/dani-garcia/vaultwarden">Vaultwarden</a></td><td>Bitwarden-compatible password manager for local secrets</td><td><code>VAULTWARDEN_VERSION</code> = 1.34.3</td><td><a href="https://github.com/dani-garcia/vaultwarden/blob/main/LICENSE.txt">AGPL-3.0</a></td></tr>
<tr><td><a href="https://github.com/CoreBunch/Instatic">Instatic</a></td><td>Self-hosted visual CMS / website builder (<code>instatic.test</code>), SQLite and uploads in <code>data/instatic/</code></td><td><code>INSTATIC_VERSION</code> = 0.0.14</td><td><a href="https://github.com/CoreBunch/Instatic/blob/main/LICENSE">MIT</a></td></tr>
<tr><td><a href="https://github.com/axllent/mailpit">Mailpit</a></td><td>SMTP catcher with a web UI, so dev mail never leaves the machine</td><td><code>MAILPIT_VERSION</code> = v1.27</td><td><a href="https://github.com/axllent/mailpit/blob/master/LICENSE">MIT</a></td></tr>
<tr><td><a href="https://rustfs.com/">RustFS</a></td><td>S3-compatible object storage for local bucket experiments</td><td><code>RUSTFS_VERSION</code> = latest</td><td><a href="https://github.com/rustfs/rustfs/blob/main/LICENSE">Apache-2.0</a></td></tr>
<tr><td><a href="https://openwa.dev/">open-wa</a></td><td>Self-hosted WhatsApp REST API gateway (image from the <code>rmyndharis/OpenWA</code> fork on GHCR)</td><td><code>OPENWA_VERSION</code> = latest</td><td><a href="https://firstdonoharm.dev/version/1/0/full.html">Hippocratic + Do Not Harm 1.0</a> (source-available, not OSI)</td></tr>
<tr><td>HeadlessX</td><td>Browser-automation platform built from source into <code>data/headlessx</code>, reusing shared Postgres and Redis</td><td>source checkout</td><td>per the upstream checkout in <code>data/headlessx</code></td></tr>
<tr><td><a href="https://playwright.dev/">Playwright</a></td><td>Warm E2E runner image with browsers preinstalled (<code>playwright.test</code>, UI mode on <code>:4527</code>)</td><td><code>PLAYWRIGHT_VERSION</code> = v1.62.1-noble</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a>; bundled browsers: Chromium <a href="https://opensource.org/license/bsd-3-clause">BSD-3-Clause</a>, Firefox <a href="https://www.mozilla.org/en-US/MPL/2.0/">MPL-2.0</a>, WebKit <a href="https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html">LGPL-2.1</a></td></tr>
</tbody>
</table>

## Utilities & monitoring

<table>
<thead><tr><th>Project</th><th>What it does in LDS</th><th>Version (env)</th><th>License</th></tr></thead>
<tbody>
<tr><td><a href="https://github.com/snapotter-hq/SnapOtter">SnapOtter</a></td><td>Self-hosted file-processing platform - 300+ convert/compress/OCR/AI tools over images, video, audio, PDF and documents, web UI + REST API (<code>snapotter.test</code>); shares the stack postgres + redis</td><td><code>SNAPOTTER_VERSION</code> = 2.2.0</td><td><a href="https://www.gnu.org/licenses/agpl-3.0.en.html">AGPL-3.0</a></td></tr>
<tr><td><a href="https://github.com/karimz1/imgcompress">ImgCompress</a></td><td>Image toolbox - 70+ input formats, bulk compression, image-to-PDF, local AI background removal, hardened single container (<code>imgcompress.test</code>)</td><td><code>IMGCOMPRESS_VERSION</code> = 0.9.0</td><td><a href="https://www.gnu.org/licenses/gpl-3.0.en.html">GPL-3.0</a></td></tr>
<tr><td><a href="https://github.com/jgraph/drawio">draw.io</a></td><td>Self-hosted diagramming, linked in offline mode (<code>drawio.test</code>)</td><td><code>DRAWIO_VERSION</code> = 31.6.1</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://github.com/lldap/lldap">LLDAP</a></td><td>Lightweight LDAP directory - auth backend for your apps; web UI kept internal, managed via DBX (<code>:4537</code>)</td><td><code>LLDAP_VERSION</code> = 2026-09-22</td><td><a href="https://www.gnu.org/licenses/gpl-3.0.en.html">GPL-3.0</a></td></tr>
<tr><td><a href="https://hub.docker.com/r/cleanstart/openldap">OpenLDAP</a></td><td>Standards-compliant LDAP directory - no web UI, managed via DBX or the LDAP CLI (<code>:4540</code>), profile <code>openldap</code></td><td><code>OPENLDAP_VERSION</code> = 2.7.1-dev</td><td><a href="https://www.openldap.org/license/">OLDAP-2.8</a></td></tr>
<tr><td><a href="https://prometheus.io/">Prometheus</a></td><td>Pull-based metrics TSDB, scrapes itself + Grafana (<code>prometheus.test</code>), profile <code>monitoring</code></td><td><code>PROMETHEUS_VERSION</code> = v3.13.4</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://grafana.com/">Grafana</a></td><td>Dashboards and alerting with the Prometheus datasource auto-provisioned (<code>grafana.test</code>), profile <code>monitoring</code></td><td><code>GRAFANA_VERSION</code> = 13.0.10</td><td><a href="https://www.gnu.org/licenses/agpl-3.0.en.html">AGPL-3.0</a></td></tr>
</tbody>
</table>

## Security & code quality

<table>
<thead><tr><th>Project</th><th>What it does in LDS</th><th>Version (env)</th><th>License</th></tr></thead>
<tbody>
<tr><td><a href="https://semgrep.dev/">Semgrep</a></td><td>SAST scanning (<code>lds tools semgrep</code>) with an SARIF report viewer at <code>semgrep.test</code></td><td><code>SEMGREP_VERSION</code> = 1.167.0</td><td><a href="https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html">LGPL-2.1</a> (engine); <a href="https://semgrep.dev/docs/licensing">Semgrep Rules License</a> (rules)</td></tr>
<tr><td><a href="https://www.zaproxy.org/">OWASP ZAP</a></td><td>DAST - proxies and scans the running apps from inside the network, desktop UI at <code>zap.test</code></td><td><code>ZAP_VERSION</code> = stable</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://trivy.dev/">Trivy</a></td><td>CVE/SCA of images, filesystems and dependencies, HTML report served by <code>trivy.test</code></td><td><code>TRIVY_VERSION</code> = 0.58.1</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://github.com/tirth8205/code-review-graph">code-review-graph (CRG)</a></td><td>AI code-intelligence graph; scanner image built from <code>configs/crg</code>, viewer at <code>crg.test</code></td><td><code>CRG_VERSION</code> = 2.3.7</td><td><a href="https://github.com/tirth8205/code-review-graph/blob/main/LICENSE">MIT</a></td></tr>
</tbody>
</table>

## Host system & CLI tools

<table>
<thead><tr><th>Project</th><th>What it does in LDS</th><th>Version (env)</th><th>License</th></tr></thead>
<tbody>
<tr><td><a href="https://www.docker.com/">Docker</a> + Compose</td><td>Runs the whole stack; Compose drives <code>lds up</code>, profiles and healthchecks</td><td>Docker Desktop / Engine on the host</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://git-scm.com/">Git</a></td><td>Version control for this repo, and the scaffolding scripts copy templates with it</td><td>host</td><td><a href="https://git-scm.com/about/free-and-open-source">GPL-2.0</a></td></tr>
<tr><td>Bash (Git Bash on Windows)</td><td>Runs <code>lds.sh</code> and every <code>scripts/*.sh</code></td><td>host</td><td><a href="https://www.gnu.org/licenses/gpl-3.0.en.html">GPL-3.0</a></td></tr>
<tr><td>PowerShell + cmd</td><td>Runs the <code>.bat</code> twins of the scripts on Windows</td><td>host</td><td>PowerShell <a href="https://github.com/PowerShell/PowerShell/blob/master/LICENSE.txt">MIT</a>; cmd is part of Windows</td></tr>
<tr><td><a href="https://github.com/FiloSottile/mkcert">mkcert</a></td><td><code>lds certs</code> mints a locally-trusted wildcard <code>*.test</code> certificate (preferred path)</td><td>host (optional)</td><td><a href="https://github.com/FiloSottile/mkcert/blob/master/LICENSE">MIT</a></td></tr>
<tr><td><a href="https://www.openssl.org/">OpenSSL</a></td><td>Fallback self-signed certificate when mkcert is not installed</td><td>host</td><td><a href="https://www.openssl.org/source/license.html">Apache-2.0</a></td></tr>
<tr><td><a href="https://curl.se/">curl</a></td><td>Downloads JDBC drivers, DuckDB, Maven and Connect plugins across the scripts</td><td>host</td><td><a href="https://curl.se/docs/copyright.html">curl license (MIT-like)</a></td></tr>
</tbody>
</table>

## Vendored in this repository

<table>
<thead><tr><th>Project</th><th>What it does in LDS</th><th>Version (env)</th><th>License</th></tr></thead>
<tbody>
<tr><td><a href="https://github.com/erusev/parsedown">Parsedown</a></td><td>Markdown to HTML for the handbook page (<code>docs.php</code>), patched for PHP 8.4's implicit-nullable deprecation</td><td>1.7.4 (<code>configs/web/dashboard/lib/</code>)</td><td><a href="https://github.com/erusev/parsedown/blob/master/LICENSE.txt">MIT</a> (<code>lib/PARSEDOWN-LICENSE.txt</code>)</td></tr>
<tr><td><a href="https://github.com/aptible/supercronic">supercronic</a></td><td>Container-safe cron baked into the dev bases and vendored for the cloud cron images</td><td>v0.2.46 (<code>assets/supersonic/</code>)</td><td><a href="https://github.com/aptible/supercronic/blob/main/LICENSE.md">MIT</a></td></tr>
<tr><td>DuckDB CLI</td><td>Binary used by local helper and seed scripts</td><td>1.2.0 (<code>assets/duckdb/</code>)</td><td><a href="https://github.com/duckdb/duckdb/blob/main/LICENSE">MIT</a></td></tr>
<tr><td>JDBC driver jars</td><td>Git-ignored binaries each developer downloads; Hop and Hive mount them single-file</td><td>pinned per jar (<code>assets/jdbc/</code>)</td><td>Mixed - see <code>assets/jdbc/README.md</code> in the Data table above</td></tr>
<tr><td>LDS brand assets</td><td>Logos, badges and icons in <code>assets/brand/</code> - drawn for this project</td><td>-</td><td>Authored for LDS (no third-party marks)</td></tr>
</tbody>
</table>

## Template & helper image bases (cloud builds)

The templates ship a second Dockerfile for the cloud/default build (K8s, Fleet,
CI). These tags are hard-coded in the templates rather than env-driven.

<table>
<thead><tr><th>Image</th><th>Used by</th><th>Version (env)</th><th>License</th></tr></thead>
<tbody>
<tr><td><a href="https://hub.docker.com/_/tomcat">tomcat</a></td><td><code>svc</code>/<code>web</code> Java servlet templates</td><td>10.1-jdk21</td><td><a href="https://www.apache.org/licenses/LICENSE-2.0">Apache-2.0</a></td></tr>
<tr><td><a href="https://hub.docker.com/_/php">php</a></td><td><code>cron-php</code> cloud image</td><td>8.4-cli-alpine</td><td><a href="https://www.php.net/license/3_01.txt">PHP-3.01</a></td></tr>
<tr><td><a href="https://hub.docker.com/_/golang">golang</a></td><td><code>cron-go</code> cloud image (build stage)</td><td>1.25-alpine</td><td><a href="https://go.dev/LICENSE">BSD-3-Clause</a></td></tr>
<tr><td><a href="https://hub.docker.com/_/node">node</a></td><td><code>cron-node</code> cloud image</td><td>22-alpine</td><td><a href="https://github.com/nodejs/node/blob/main/LICENSE">MIT</a></td></tr>
<tr><td><a href="https://hub.docker.com/_/python">python</a></td><td><code>cron-python</code> cloud image and the CRG scanner</td><td>3.12-slim</td><td><a href="https://docs.python.org/3/license.html">PSF-2.0</a></td></tr>
<tr><td><a href="https://hub.docker.com/_/alpine">alpine</a></td><td><code>cron-shell</code> cloud image</td><td>3.20</td><td>Mixed (per package)</td></tr>
<tr><td><a href="https://hub.docker.com/_/debian">debian</a></td><td><code>base-images/php</code> and the DuckDB helper image</td><td>13-slim</td><td><a href="https://www.debian.org/legal/">Mixed (per package)</a></td></tr>
</tbody>
</table>

> LDS's own services - the control panel, connector builder, DNS image, seed
> and init scripts, the analytics/tasks/wiki apps, and the Text diff + Palette
> generator utilities under <code>configs/web/dashboard/tools/</code> - are
> authored in this repository and carry no third-party license. Everything
> above is credited because it is not ours. Versions drift: the authoritative
> defaults are `.env.example` and `docker-compose.yml`.
