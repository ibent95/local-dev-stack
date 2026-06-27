# 09 · Kafka + Debezium

Broker berjalan mode KRaft dengan controller terpisah. Layanan `connect` adalah
Debezium, jadi Anda bisa mengalirkan perubahan baris dari MySQL/Postgres ke
topik Kafka.

1. Jalankan `kafka` + profile DB yang diinginkan: `./lds.sh up kafka mysql`.
2. Pastikan DB punya data dan hak yang sesuai (MySQL: hak REPLICATION; Postgres:
   role yang boleh membuat replication slot — user `app` bawaan cukup untuk lokal).
3. `./lds.sh register-connectors` (atau `register-connectors mysql`).
4. Pantau topik muncul di Kafka UI: http://localhost:4420.

Endpoint: Kafka UI `:4420`, Schema Registry `:4411`, Connect REST — Debezium
`:4413`, generic `:4412`; broker `localhost:4410` (host) /
`kafka-broker:9092` (dalam jaringan). Edit
config connector di `configs/kafka/connect/*.json`.
