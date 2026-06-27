# 03 · First run

Everything goes through the `lds` wrapper (`./lds.sh <cmd>`, or `lds.bat` on cmd):

1. `cp .env.example .env`
2. `./lds.sh init` — create the shared `lds-network` network (once).
3. `./lds.sh build-bases` — build the shared `lds/*` base images (once; `up`
   also auto-builds the `lds/php` base if it's missing).
4. (Optional) generate a Kafka cluster id and set `KAFKA_CLUSTER_ID`:
   `docker run --rm apache/kafka:3.9.1 /opt/kafka/bin/kafka-storage.sh random-uuid`
5. `./lds.sh up all` — or a subset of profiles, e.g. `./lds.sh up mysql redis`.
