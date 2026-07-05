# Generic Kafka Connect — plugins

This directory is mounted into the **generic** Connect worker at its
`plugin.path` (`/opt/kafka/connectors`). The worker ships **empty** except for
Kafka's built-in MirrorMaker connectors (`MirrorSource`/`MirrorCheckpoint`/
`MirrorHeartbeat`) — drop connector plugins here to add more.

This stack is **Confluent-free**, so use Apache-2.0 connectors (e.g. Aiven's).
For CDC (MySQL/Postgres/Mongo) use the **debezium** worker instead — it already
bundles those.

## Add a connector

```bash
lds connect-plugin jdbc          # known Apache-2.0 connectors: jdbc, s3, http, opensearch
lds connect-plugin <URL> [name]  # any connector .zip / .tar(.gz) release by URL
```

It downloads + extracts the connector into `plugins/<name>/`. Then load it:

```bash
docker restart lds-kafka-connect-generic
# verify:
curl -s localhost:4412/connector-plugins
```

The resolver scans recent releases (newest first) and picks the latest one that
actually ships a **built** archive asset — some releases attach only GitHub's
auto-generated *source* tarball, which isn't a usable plugin. If resolution ever
fails (offline / API down), pass the release URL directly:
`lds kafka connect-plugin --generic <release-archive-URL> [name]`.

The Aiven `jdbc` connector bundles MySQL, PostgreSQL, MSSQL and SQLite JDBC
drivers, so it talks to the stack DBs out of the box (no extra driver needed).

## Manual install

Extract a connector's release archive so its JARs land under a subfolder here,
e.g. `plugins/jdbc/…jars`, then restart the worker. Each immediate subdirectory
of this folder is scanned as a plugin.

## Known Apache-2.0 connectors

<table>
<thead>
<tr>
<th>short</th>
<th>repo</th>
</tr>
</thead>
<tbody>
<tr>
<td>`jdbc`</td>
<td>Aiven-Open/jdbc-connector-for-apache-kafka</td>
</tr>
<tr>
<td>`s3`</td>
<td>Aiven-Open/s3-connector-for-apache-kafka</td>
</tr>
<tr>
<td>`http`</td>
<td>Aiven-Open/http-connector-for-apache-kafka</td>
</tr>
<tr>
<td>`opensearch`</td>
<td>Aiven-Open/opensearch-connector-for-apache-kafka</td>
</tr>
</tbody>
</table>

> Note: everything here except this README and `.gitkeep` is git-ignored — the
> JARs are downloaded artifacts, not committed.
