# =============================================================================
# Micronaut — dev run via lds/java-dev. Scaffold a Maven project into ./src
# (pom.xml at src root) from https://launch.micronaut.io first.
# Prod: `mvn package` then run the produced target/*.jar (see README).
# =============================================================================
FROM lds/java-dev:21 AS dev
WORKDIR /app
EXPOSE 8080
CMD ["mvn", "mn:run"]
