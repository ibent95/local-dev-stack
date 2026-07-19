# =============================================================================
# Base image: lds/php — the ONE PHP base. php-fpm + extensions + composer
# + nginx + supervisor, with the global default configs/php-app/* baked in.
# supervisord (default CMD) runs php-fpm + nginx; each toggled by an env var.
# Consumers:
#   - the LDS mass-vhost `php` service (mounts its own nginx config),
#   - every PHP template (FROM lds/php; adds workers / overrides as needed),
#   - Webman (overrides CMD to run its own server).
# Built from the REPO ROOT so it can COPY configs/php-app/* (./lds.sh build-bases).
# -----------------------------------------------------------------------------
# Debian 13 (Trixie) ships PHP 8.4 natively in its repositories. We build on
# Docker's official debian:13-slim image and install php-fpm, nginx, supervisor,
# and all extensions from Debian repos via apt. rdkafka and apfd are compiled
# via PECL since they lack Debian packages.
# Compat shims keep the official-image layout the configs/mounts expect:
#   php-fpm on $PATH, fpm on 127.0.0.1:9000, inis in /usr/local/etc/php/conf.d.
# =============================================================================
FROM debian:13-slim

# DHI defaults to a non-root user; the build (and supervisord/nginx on :80 at
# runtime) need root.
USER root

# Install php-fpm, nginx, supervisor, extra extensions, and build deps.
# Build deps (php8.4-dev, php-pear, gcc, make, autoconf, librdkafka-dev) are
# installed as part of this same apt-get command, then purged after PECL runs.
# librdkafka1 is explicitly apt-mark'd as manually installed so it survives
# the autoremove (rdkafka.so needs librdkafka1 at runtime).
RUN apt-get update && apt-get install -y --no-install-recommends \
        nginx supervisor git curl wget unzip ca-certificates \
        php8.4-fpm \
        php8.4-mysql php8.4-pgsql php8.4-intl php8.4-bcmath php8.4-gd \
        php8.4-zip php8.4-mbstring php8.4-curl \
        php8.4-sockets php8.4-xml \
        php-redis php-memcached \
        librdkafka1 \
        php8.4-dev php-pear gcc make autoconf librdkafka-dev \
    && apt-mark manual librdkafka1 \
    && BUILD_DEPS="php8.4-dev php-pear gcc make autoconf librdkafka-dev" \
    # --- PECL extensions (no Debian packages) ---
    # rdkafka: Apache 2.0, needed for Kafka produce/consume from PHP
    && pecl install rdkafka \
    && echo 'extension=rdkafka' > /etc/php/8.4/mods-available/rdkafka.ini \
    && phpenmod rdkafka \
    # apfd: needed for PHP-FPM's apfd status page
    && pecl install apfd \
    && echo 'extension=apfd' > /etc/php/8.4/mods-available/apfd.ini \
    && phpenmod apfd \
    # --- Clean up build dependencies ---
    && apt-get purge -y $BUILD_DEPS \
    && apt-get autoremove -y --purge \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    # --- Compat shims for compose mounts and supervisord ---
    # 1) FPM pool: listen on TCP 127.0.0.1:9000, run as www-data (Debian web
    #    user) so served apps can write to the filesystem
    && sed -ri \
        's#^listen = .*#listen = 127.0.0.1:9000#; s#^user = .*#user = www-data#; s#^group = .*#group = www-data#' \
        /etc/php/8.4/fpm/pool.d/www.conf \
    # 2) /usr/local/etc/php/conf.d -> Debian's FPM conf.d (where the compose
    #    php service mounts php.ini / opcache.ini). Make CLI share the same
    #    conf.d so `php -i` and composer see the same settings.
    && mkdir -p /usr/local/etc/php \
    && ln -sfn /etc/php/8.4/fpm/conf.d /usr/local/etc/php/conf.d \
    && rm -rf /etc/php/8.4/cli/conf.d \
    && ln -sfn /etc/php/8.4/fpm/conf.d /etc/php/8.4/cli/conf.d \
    # 3) php-fpm: Debian package installs /usr/sbin/php-fpm8.4, but supervisord
    #    expects 'php-fpm' on PATH. Create a symlink so it can be found.
    && ln -sf /usr/sbin/php-fpm8.4 /usr/local/sbin/php-fpm \
    # 4) nginx: remove Debian's default site, create runtime directories.
    && rm -f /etc/nginx/sites-enabled/default \
    && mkdir -p /run/nginx /run/php /etc/supervisor/conf.d

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# supercronic — static Go binary, works on both musl and glibc.
COPY assets/supersonic/v0.2.46/supercronic-linux-amd64 /usr/local/bin/supercronic
RUN chmod +x /usr/local/bin/supercronic

COPY configs/php-app/supervisord.conf /etc/supervisor/supervisord.conf
COPY configs/php-app/nginx.conf       /etc/nginx/conf.d/default.conf

WORKDIR /var/www/html

ENV ENABLE_PHP=true \
    ENABLE_NGINX=true \
    ENABLE_CRON=false

EXPOSE 80
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
