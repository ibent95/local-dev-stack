# svc-template-quarkus

Quarkus **API** (Java), live-coding via `mvn quarkus:dev` on `lds/java-dev`,
routed at `http://svc-template-quarkus.test` (:8080).

> Web counterpart: `web-template-quarkus`.

## 1. Scaffold (once)

Generate a Maven project from **https://code.quarkus.io** (Build Tool: Maven;
add the `rest-jackson` extension), then unzip its **contents** into `src/` so
`src/pom.xml` exists.

> Tip: keep the project files at the `src/` root (not in a sub-folder).
> Verify the Quarkus version on the launcher; commands below are version-stable.

## 2. Run

```bash
../../scripts/run/up.sh proxy
docker compose up -d        # http://svc-template-quarkus.test (live reload)
```

## Production

```bash
docker compose run --rm app mvn package
# run target/quarkus-app/quarkus-run.jar on an eclipse-temurin:21-jre image
```
