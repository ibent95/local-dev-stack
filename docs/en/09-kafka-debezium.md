# 09 · Kafka + Debezium

The broker runs in KRaft mode with a separate controller. The `connect` service
is Debezium, so you can stream row changes from MySQL/Postgres into Kafka topics.

1. Start `kafka` + the DB profile you want: `./lds.sh up kafka mysql`.
2. Ensure the DB has data and the right permissions (MySQL: REPLICATION
   privileges; Postgres: a role allowed to create a replication slot — the
   default `app` user works locally).
3. `./lds.sh register-connectors` (or `register-connectors mysql`).
4. Watch topics appear in Kafka UI: http://localhost:4420.

Endpoints: Kafka UI `:4420`, Schema Registry `:4411`, Connect REST — Debezium
`:4413`, generic `:4412`; broker `localhost:4410` (host) /
`kafka-broker:9092` (in-network). Edit
connector configs in `configs/kafka/connect/*.json`.
