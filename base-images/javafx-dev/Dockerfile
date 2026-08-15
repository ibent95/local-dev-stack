# =============================================================================
# Base image: lds/javafx-dev — JDK + Maven + JavaFX desktop build/runtime deps.
# FROM lds/java-dev (DHI eclipse-temurin dev flavor + Maven), adds the native
# libraries JavaFX needs on Linux (GTK3, fontconfig, X) so `mvn javafx:run`
# and jpackage work in the container. The OpenJFX jars themselves come from
# Maven Central at build time (declared in the app's pom.xml), so no JavaFX
# SDK download is needed here.
# =============================================================================
ARG JAVA_VERSION=25
FROM lds/java-dev:${JAVA_VERSION}

USER root

# JavaFX on Linux needs GTK3 + fontconfig + X11 libs at runtime; jpackage also
# wants glibc-locales + unzip. Install them now so `mvn javafx:run` works.
RUN apk add --no-cache \
        gtk+3.0 \
        fontconfig \
        font-noto \
        libx11 \
        libxcomposite \
        libxrender \
        libxtst \
        libxi \
        mesa-gl \
        unzip \
        binutils \
        bash \
    && rm -rf /var/cache/apk/*

# jpackage's jlink step needs objcopy (binutils) to strip the runtime image.
# (The package is already installed above; keep this note next to the install.)

# The LDS language bases (rust-dev/java-dev) run as root — they override DHI's
# non-root default — so builds here run as root too (no `app` user exists).
USER root

WORKDIR /app
