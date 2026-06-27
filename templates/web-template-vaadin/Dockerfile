# =============================================================================
# Vaadin (Flow, free core / Apache-2.0) — Spring Boot based; dev via lds/java-dev.
# Scaffold a Maven project into ./src (pom.xml at src root) from
# https://start.vaadin.com first. Prod: `mvn package -Pproduction` (see README).
# =============================================================================
FROM lds/java-dev:21 AS dev
WORKDIR /app
EXPOSE 8080
CMD ["mvn", "spring-boot:run"]
