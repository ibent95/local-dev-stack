# web-template-micronaut

Micronaut **web app** (Java, server-rendered views), dev run via `mvn mn:run` on
`lds/java-dev`, routed at `http://web-template-micronaut.test` (:8080).

> API counterpart: `svc-template-micronaut`.

## 1. Scaffold (once)

Generate a Maven app from **https://launch.micronaut.io** (add the
`views-thymeleaf` feature for server-side templates), unzip its contents into
`src/` so `src/pom.xml` exists. Or:

```bash
curl -L "https://launch.micronaut.io/create/default/com.example.app?build=maven&features=views-thymeleaf" -o app.zip
```

## 2. Run

```bash
../../scripts/run/up.sh proxy
docker compose up -d        # http://web-template-micronaut.test
```

## Production

```bash
docker compose run --rm app mvn package
# run the produced target/*.jar on an eclipse-temurin:21-jre image
```
