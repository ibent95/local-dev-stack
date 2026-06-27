# svc-template-micronaut

Micronaut **API** (Java), dev run via `mvn mn:run` on `lds/java-dev`, routed at
`http://svc-template-micronaut.test` (:8080).

> Web counterpart: `web-template-micronaut`.

## 1. Scaffold (once)

Generate a Maven app from **https://launch.micronaut.io** (Build: Maven;
Application Type: Micronaut Application), unzip its **contents** into `src/` so
`src/pom.xml` exists. Or via the API:

```bash
curl -L "https://launch.micronaut.io/create/default/com.example.app?build=maven" -o app.zip
# unzip app.zip into src/ (pom.xml at src root)
```

## 2. Run

```bash
../../scripts/run/up.sh proxy
docker compose up -d        # http://svc-template-micronaut.test
```

## Production

```bash
docker compose run --rm app mvn package
# run the produced target/*.jar on an eclipse-temurin:21-jre image
```
