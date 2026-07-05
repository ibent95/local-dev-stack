# 12 · Ports

All host ports live in the **`44xx`** block so they don't clash with anything
else on your machine. Each one is set by a `*_HOST_PORT` variable in `.env`.

<table>
<thead>
<tr>
<th>Group</th>
<th>Service</th>
<th>Host + Port</th>
<th>From Container + Port</th>
</tr>
</thead>
<tbody>
    <tr>
        <td colspan="4">
            **Data** `440x`
        </td>
    </tr>
<tr>
<td></td>
<td>MySQL</td>
<td>`localhost:4400`</td>
<td>`mysql:3306`</td>
</tr>
<tr>
<td></td>
<td>PostgreSQL</td>
<td>`localhost:4401`</td>
<td>`postgres:5432`</td>
</tr>
<tr>
<td></td>
<td>MongoDB</td>
<td>`localhost:4402`</td>
<td>`mongo:27017`</td>
</tr>
<tr>
<td></td>
<td>Redis</td>
<td>`localhost:4403`</td>
<td>`redis:6379`</td>
</tr>
<tr>
<td></td>
<td>Memcached</td>
<td>`localhost:4404`</td>
<td>`memcached:11211`</td>
</tr>
<tr>
<td>**Kafka** `441x` ---------------------------------------------------------------------------------</td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td></td>
<td>Broker (bootstrap)</td>
<td>`localhost:4410`</td>
<td>`kafka-broker:9092`</td>
</tr>
<tr>
<td></td>
<td>Schema Registry</td>
<td>`localhost:4411`</td>
<td>`schema-registry:8080`</td>
</tr>
<tr>
<td></td>
<td>Connect — generic</td>
<td>`localhost:4412`</td>
<td>`connect-generic:8083`</td>
</tr>
<tr>
<td></td>
<td>Connect — Debezium</td>
<td>`localhost:4413`</td>
<td>`connect-debezium:8083`</td>
</tr>
<tr>
<td>**Web UIs** `442x+` ------------------------------------------------------------------------------</td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td></td>
<td>Kafka UI</td>
<td>`localhost:4420`</td>
<td>`kafka-ui:8080`</td>
</tr>
<tr>
<td></td>
<td>phpCacheAdmin</td>
<td>`localhost:4421` (`cache.test`)</td>
<td>`phpcacheadmin:80`</td>
</tr>
<tr>
<td></td>
<td>DBGate</td>
<td>`localhost:4422` (`db.test`)</td>
<td>`dbgate:3000`</td>
</tr>
<tr>
<td></td>
<td>DrawDB</td>
<td>`localhost:4423` (open here, **not** `drawdb.test`)</td>
<td>`drawdb:80`</td>
</tr>
<tr>
<td></td>
<td>Apache Hop</td>
<td>`localhost:4424` (`hop.test`)</td>
<td>`hop:8080`</td>
</tr>
<tr>
<td></td>
<td>Apache Superset</td>
<td>`localhost:4425` (`superset.test`)</td>
<td>`superset:8088`</td>
</tr>
<tr>
<td></td>
<td>Semgrep viewer</td>
<td>`localhost:4426` (`semgrep.test`)</td>
<td>`semgrep:80`</td>
</tr>
<tr>
<td></td>
<td>InsightTrack UI</td>
<td>`localhost:4427` (`insighttrack.test`)</td>
<td>`insighttrack:4173`</td>
</tr>
<tr>
<td></td>
<td>InsightTrack API</td>
<td>`localhost:4428`</td>
<td>`insighttrack-backend:3001`</td>
</tr>
<tr>
<td></td>
<td>Vaultwarden</td>
<td>`localhost:4429` (`vaultwarden.test`)</td>
<td>`vaultwarden:80`</td>
</tr>
<tr>
<td></td>
<td>Werkyn</td>
<td>`localhost:4435` (`werkyn.test`)</td>
<td>`werkyn:3000`</td>
</tr>
<tr>
<td>**Realtime** `443x` ------------------------------------------------------------------------------</td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td></td>
<td>Soketi (Pusher)</td>
<td>`localhost:4430` (`ws.test`)</td>
<td>`soketi:6001`</td>
</tr>
<tr>
<td></td>
<td>Centrifugo + UI</td>
<td>`localhost:4431` (`centrifugo.test`)</td>
<td>`centrifugo:8000`</td>
</tr>
<tr>
<td></td>
<td>Mosquitto — MQTT</td>
<td>`localhost:4432`</td>
<td>`mosquitto:1883`</td>
</tr>
<tr>
<td></td>
<td>Mosquitto — MQTT/WS</td>
<td>`localhost:4433` (path `/`)</td>
<td>`mosquitto:9001`</td>
</tr>
<tr>
<td></td>
<td>MQTTX Web client</td>
<td>`localhost:4434` (`mqtt.test`)</td>
<td>`mqttx:80`</td>
</tr>
<tr>
<td>**Infra** ----------------------------------------------------------------------------------------</td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td></td>
<td>Web proxy</td>
<td>`localhost:80` (`*.test`)</td>
<td>—</td>
</tr>
<tr>
<td></td>
<td>Web proxy (HTTPS)</td>
<td>`localhost:443` (`*.test`, opt-in)</td>
<td>—</td>
</tr>
<tr>
<td></td>
<td>DNS</td>
<td>`localhost:53` (udp + tcp)</td>
<td>—</td>
</tr>
</tbody>
</table>

- **From the host**, connect to `localhost:<port>` (left column).
- **From another container** on `lds-network`, use the service name + its
  internal port (right column) — these never change when you remap host ports.
- **Infra stays put:** the web proxy keeps `80` (clean `http://app.test` URLs,
  no port suffix) and DNS keeps `53` (the OS resolver queries port 53 to resolve
  `*.test`).
- **Control panel:** `http://localhost` (served by the php container, the proxy's
  default route) lists every tool + project — see [15 · Dashboard & data tools](15-data-tools.md).
- **DrawDB exception:** open it at `localhost:4423`, **not** `drawdb.test` over
  http — it needs a secure context (`localhost` or HTTPS) for `crypto.randomUUID`.
- **HTTPS is opt-in:** port `443` (`WEB_HTTPS_PORT`) is published only when
  `LDS_ENABLE_HTTPS=true`. Run `lds certs` once to mint the wildcard `*.test`
  dev cert — see [13 · Profiles](13-profiles.md) → *TLS / certificates*.
- To change a host port, edit its `*_HOST_PORT` in `.env` (e.g.
  `MYSQL_HOST_PORT=4400`), then recreate the containers: `lds down && lds up`.
