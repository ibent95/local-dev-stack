# web-template-quarkus

Quarkus **web app** (Java, server-rendered with Qute), live-coding via
`mvn quarkus:dev`, routed at `http://web-template-quarkus.test` (:8080).

> API counterpart: `svc-template-quarkus`.

## 1. Scaffold (once)

Generate a Maven project from **https://code.quarkus.io** (Maven; add the
`rest-qute` extension for server-side templates), unzip its contents into `src/`
so `src/pom.xml` exists.

## 2. Run

```bash
../../scripts/run/up.sh proxy
docker compose up -d        # http://web-template-quarkus.test (live reload)
```

## Production

```bash
docker compose run --rm app mvn package
# run target/quarkus-app/quarkus-run.jar on an eclipse-temurin:21-jre image
```
