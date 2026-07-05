# =============================================================================
# Spring Boot — dev (spring-boot:run + devtools) from lds/java-dev.
# =============================================================================
FROM lds/java-dev:21
WORKDIR /app
COPY pom.xml ./
RUN mvn -q -B dependency:go-offline || true
COPY . .
EXPOSE 8080
CMD ["mvn", "-q", "-B", "spring-boot:run"]
