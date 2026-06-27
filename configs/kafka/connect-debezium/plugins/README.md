# Debezium worker — EXTRA connector plugins

The `connect-debezium` worker bundles Debezium's CDC source connectors (MySQL,
Postgres, Mongo, …) + a JDBC sink **inside its image** (plugin path `/kafka/connect`).
This host-mounted dir is an ADDITIONAL plugin path (`/kafka/connect-extra`, via
`CONNECT_PLUGIN_PATH`) for connectors Debezium does NOT bundle — so you can run
non-CDC connectors on the same worker.

Add one (only the connectors Debezium is missing — don't re-add its CDC ones):

```bash
lds kafka connect-plugin --debezium mqtt     # or s3 | http | opensearch | <URL>
docker restart lds-kafka-connect-debezium
curl -s localhost:4413/connector-plugins
```

The same helper installs to the generic worker with `--generic` (the default).
Pre-seeded here: mqtt, s3, http, opensearch (copied from the generic worker;
JDBC was skipped because Debezium already provides a JDBC sink).

> Jars are git-ignored (downloaded artifacts). See docs/en/15-data-tools.md.
