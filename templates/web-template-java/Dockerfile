# =============================================================================
# Native Java (Servlet) — built to a WAR with lds/java-dev, run on Tomcat.
# Servlets don't hot-reload; apply changes with `docker compose up -d --build`.
# =============================================================================
FROM lds/java-dev:21 AS build
WORKDIR /app
COPY pom.xml ./
RUN mvn -q -B dependency:go-offline || true
COPY . .
RUN mvn -q -B -DskipTests package

FROM tomcat:10.1-jdk21
RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=build /app/target/ROOT.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
