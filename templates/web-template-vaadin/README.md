# web-template-vaadin

Vaadin **web app** (Java UI framework — Flow core is free, Apache-2.0; built on
Spring Boot), dev via `mvn spring-boot:run` on `lds/java-dev`, routed at
`http://web-template-vaadin.test` (:8080).

Vaadin is a UI framework, so it's **web-only** (no `svc-` counterpart).

## 1. Scaffold (once)

Generate a starter from **https://start.vaadin.com** (a Spring Boot + Vaadin
Maven project), unzip its **contents** into `src/` so `src/pom.xml` exists.
Use only free (Apache-2.0) components to stay license-free.

## 2. Run

```bash
../../scripts/run/up.sh proxy
docker compose up -d        # http://web-template-vaadin.test (first build is slow)
```

> Spring Boot's default host check is permissive; if you hit a host error,
> ensure the app binds `0.0.0.0` (Spring Boot does by default).

## Production

```bash
docker compose run --rm app mvn package -Pproduction
# run the produced target/*.jar on an eclipse-temurin:21-jre image
```
