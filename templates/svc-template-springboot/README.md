# svc-template-springboot

Java + Spring Boot (Maven) service with **devtools** hot-restart, routed via
nginx-proxy at `http://svc-template-springboot.test`.

## Run

```powershell
../../scripts/run/up.sh proxy     # once
docker compose up -d               # http://svc-template-springboot.test (first build is slow)
```

The `maven-cache` volume keeps `~/.m2` warm. With `spring-boot:run` + devtools,
the app restarts when classes are recompiled. For full live reload, run a
watch build in another shell:

```powershell
docker compose exec java mvn compile   # triggers devtools restart
```

## Make your own

Copy into `D:\projects\Java\my-service`, set `APP_HOST`, adjust the package
name, `docker compose up -d`.

## Backing services

`mysql:3306`, `postgres:5432`, `redis:6379`, `kafka-broker:9092` on `lds-network`
(add the matching Spring starter, e.g. `spring-boot-starter-data-jpa`).

## Production image

```powershell
docker build --target prod -t my-service:prod .
```
