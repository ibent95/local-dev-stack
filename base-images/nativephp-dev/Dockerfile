# =============================================================================
# Base image: lds/nativephp-dev — PHP + Composer + Node build image for the
# NativePHP variant of the LDS Desktop app (variant C, learning only).
#
# FROM lds/php (the ONE PHP base: PHP 8.4 CLI + composer + node 20 + git +
# ext-zip/curl/mbstring), so the nativephp toolchain is already present. This
# layer adds what Laravel's default SQLite database and composer-patches need:
#   php*-sqlite3   pdo_sqlite driver (Laravel default DB)
#   patch          fallback for cweagans/composer-patches (git apply is primary)
#
# Like tauri-dev/javafx-dev, container builds are a COMPILE CHECK: NativePHP
# packages per-OS installers via Electron on the host, so `desktop/build.sh
# nativephp` verifies composer install (patch applies), the Vite build, and an
# artisan console boot — it does not produce an installer.
#
# Runs as root (lds/php's default user) — fine for compile-check artifacts on
# Windows bind mounts.
# =============================================================================
ARG PHP_VERSION=8.4
FROM lds/php:${PHP_VERSION}
ARG PHP_VERSION

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        php${PHP_VERSION}-sqlite3 \
        patch \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
