# =============================================================================
# Spring Boot — dev (spring-boot:run + devtools) from lds/java-dev; prod = JRE + jar.
# =============================================================================
FROM lds/java-dev:21 AS base
WORKDIR /app
COPY pom.xml ./
RUN mvn -q -B dependency:go-offline || true

FROM base AS dev
COPY . .
EXPOSE 8080
CMD ["mvn", "-q", "-B", "spring-boot:run"]

FROM base AS builder
COPY . .
RUN mvn -q -B -DskipTests package

FROM eclipse-temurin:21-jre AS prod
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
