# 12 · Ports

All host ports live in the **`44xx`** block so they don't clash with anything
else on your machine. Each one is set by a `*_HOST_PORT` variable in `.env`.

|       Group        |      Service       |           Host + Port           |  From Container + Port  |
|--------------------|--------------------|---------------------------------|-------------------------|
| **Data** `440x` ----------------------------------------------------------------------------------|||
|                    | MySQL              | `localhost:4400`                | `mysql:3306`            |
|                    | PostgreSQL         | `localhost:4401`                | `postgres:5432`         |
|                    | MongoDB            | `localhost:4402`                | `mongo:27017`           |
|                    | Redis              | `localhost:4403`                | `redis:6379`            |
|                    | Memcached          | `localhost:4404`                | `memcached:11211`       |
| **Kafka** `441x` ---------------------------------------------------------------------------------|||
|                    | Broker (bootstrap) | `localhost:4410`                | `kafka-broker:9092`     |
|                    | Schema Registry    | `localhost:4411`                | `schema-registry:8080`  |
|                    | Connect — generic  | `localhost:4412`                | `connect-generic:8083`  |
|                    | Connect — Debezium | `localhost:4413`                | `connect-debezium:8083` |
| **Web UIs** `442x+` ------------------------------------------------------------------------------|||
|                    | Kafka UI           | `localhost:4420`                | `kafka-ui:8080`         |
|                    | phpCacheAdmin      | `localhost:4421` (`cache.test`) | `phpcacheadmin:80`      |
|                    | DBGate             | `localhost:4422` (`db.test`)    | `dbgate:3000`           |
|                    | DrawDB             | `localhost:4423` (open here, **not** `drawdb.test`) | `drawdb:80` |
|                    | Apache Hop         | `localhost:4424` (`hop.test`)   | `hop:8080`              |
|                    | Apache Superset    | `localhost:4425` (`superset.test`) | `superset:8088`      |
|                    | Semgrep viewer     | `localhost:4426` (`semgrep.test`) | `semgrep:80`          |
|                    | InsightTrack UI    | `localhost:4427` (`insighttrack.test`) | `insighttrack:4173` |
|                    | InsightTrack API   | `localhost:4428`                | `insighttrack-backend:3001` |
|                    | Vaultwarden        | `localhost:4429` (`vaultwarden.test`) | `vaultwarden:80`    |
|                    | Werkyn             | `localhost:4435` (`werkyn.test`) | `werkyn:3000`          |
| **Realtime** `443x` ------------------------------------------------------------------------------|||
|                    | Soketi (Pusher)    | `localhost:4430` (`ws.test`)    | `soketi:6001`           |
|                    | Centrifugo + UI    | `localhost:4431` (`centrifugo.test`) | `centrifugo:8000`  |
|                    | Mosquitto — MQTT   | `localhost:4432`                | `mosquitto:1883`        |
|                    | Mosquitto — MQTT/WS | `localhost:4433` (path `/`)     | `mosquitto:9001`        |
|                    | MQTTX Web client   | `localhost:4434` (`mqtt.test`)  | `mqttx:80`              |
| **Infra** ----------------------------------------------------------------------------------------|||
|                    | Web proxy          | `localhost:80` (`*.test`)       |            —            |
|                    | Web proxy (HTTPS)  | `localhost:443` (`*.test`, opt-in) |         —            |
|                    | DNS                | `localhost:53` (udp + tcp)      |            —            |

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
