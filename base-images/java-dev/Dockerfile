# =============================================================================
# Base image: lds/java-dev — Maven + JDK for building Spring Boot / Servlet apps.
# (Runtime images stay upstream: tomcat for Servlets, temurin-jre for Spring.)
# Now FROM the DHI eclipse-temurin dev flavor (JDK + shell). DHI does not
# publish a maven:* image, so Maven is installed from the Apache binary dist.
# =============================================================================
ARG DHI_REGISTRY=dhi.io
ARG JAVA_VERSION=25
FROM ${DHI_REGISTRY}/eclipse-temurin:${JAVA_VERSION}-jdk-alpine3.24-dev

# DHI defaults to a non-root user; the Maven install + COPY below need root.
USER root

# Apache Maven (the upstream maven:* convenience image is not DHI-published).
# Alpine's busybox provides wget (https-capable) + gzip-aware tar, so no apk
# install is needed to fetch + unpack it.
ARG MAVEN_VERSION=3.9.16
RUN set -eux; \
    wget -O /tmp/maven.tar.gz \
        "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"; \
    tar -xzf /tmp/maven.tar.gz -C /opt; \
    mkdir -p /usr/local/bin; \
    ln -sf "/opt/apache-maven-${MAVEN_VERSION}/bin/mvn" /usr/local/bin/mvn; \
    rm /tmp/maven.tar.gz
ENV MAVEN_HOME=/opt/apache-maven-${MAVEN_VERSION}

# supercronic — container cron for cron-* templates (vendored amd64 from assets/,
# no network download; this base builds from the repo root — see docker-bake.hcl).
COPY assets/supersonic/v0.2.46/supercronic-linux-amd64 /usr/local/bin/supercronic
RUN chmod +x /usr/local/bin/supercronic

WORKDIR /app
