# 03 · Menjalankan pertama kali

Semua lewat wrapper `lds` (`./lds.sh <cmd>`, atau `lds.bat` di cmd):

1. `cp .env.example .env`
2. `./lds.sh init` — buat jaringan bersama `lds-network` (sekali saja).
3. `./lds.sh build-bases` — build base image bersama `lds/*` (sekali saja; `up`
   juga otomatis mem-build base `lds/php` bila belum ada).
4. (Opsional) buat cluster id Kafka lalu set `KAFKA_CLUSTER_ID`:
   `docker run --rm apache/kafka:3.9.1 /opt/kafka/bin/kafka-storage.sh random-uuid`
5. `./lds.sh up all` — atau sebagian profile, mis. `./lds.sh up mysql redis`.
