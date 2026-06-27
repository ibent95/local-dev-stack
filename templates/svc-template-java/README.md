# svc-template-java

Java **API** using the native **Servlet API** (Jakarta Servlet, no framework),
built to a WAR and run on Tomcat. Routed at `http://svc-template-java.test`.
Returns JSON.

> Web counterpart: `web-template-java`. Framework version: `svc-template-springboot`.

## Run

```bash
../../scripts/run/up.sh proxy            # once
docker compose up -d                     # http://svc-template-java.test (first build is slow)
```

Servlets don't hot-reload from a source mount — after editing
`src/main/java/com/example/ApiServlet.java`, rebuild:

```bash
docker compose up -d --build
```

## Backing services

`mysql:3306`, `postgres:5432`, `redis:6379`, `kafka-broker:9092` on `lds-network`.

## Production image

```bash
docker build --target prod -t svc-java:prod .
```
