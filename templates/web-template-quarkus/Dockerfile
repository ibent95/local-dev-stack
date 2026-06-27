# =============================================================================
# Quarkus — dev (live coding) via lds/java-dev. Scaffold a Maven project into
# ./src (pom.xml at src root) from https://code.quarkus.io first.
# Prod: `mvn package` then run target/quarkus-app/quarkus-run.jar (see README).
# =============================================================================
FROM lds/java-dev:21 AS dev
WORKDIR /app
EXPOSE 8080
CMD ["mvn", "quarkus:dev", "-Dquarkus.http.host=0.0.0.0"]
