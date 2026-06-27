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
# DHI's php images split build (`-dev`: no php-fpm, no docker-php-ext-* helpers)
# from a hardened fpm runtime (no shell/apk) — neither can host this fat single
# container. So we build on the DHI alpine-base and install php-fpm + the
# extensions + nginx + supervisor from Alpine's repos (php = php84). rdkafka,
# redis and memcached ship as apk packages (php84-pecl-*, which auto-enable
# their own conf.d ini); only apfd has no package, so it's built via PECL.
# Alpine's curated DHI repo carries no php, so we add the upstream Alpine
# main+community repos (same shape as debian-base pulling php from Debian).
# Compat shims below keep the official-image layout the configs/mounts expect:
#   php-fpm on $PATH, fpm on 127.0.0.1:9000, inis in /usr/local/etc/php/conf.d.
# =============================================================================
ARG DHI_REGISTRY=dhi.io
ARG ALPINE_VERSION=3.24
FROM ${DHI_REGISTRY}/alpine-base:${ALPINE_VERSION}-dev

# DHI defaults to a non-root user; the build (and supervisord/nginx on :80 at
# runtime) need root.
USER root

ARG ALPINE_VERSION=3.24
# php lives in upstream Alpine community (the DHI alpine repo has no php), so add
# the matching upstream main+community. Leading \n so it lands on its own line.
RUN printf '\nhttps://dl-cdn.alpinelinux.org/alpine/v%s/main\nhttps://dl-cdn.alpinelinux.org/alpine/v%s/community\n' \
        "$ALPINE_VERSION" "$ALPINE_VERSION" >> /etc/apk/repositories \
    && apk add --no-cache \
        nginx supervisor git curl unzip \
        php84 php84-fpm \
        php84-pdo_mysql php84-pdo_pgsql php84-intl php84-bcmath php84-gd \
        php84-zip php84-mbstring php84-curl php84-opcache php84-sockets \
        php84-phar php84-openssl php84-iconv php84-fileinfo php84-ctype \
        php84-session php84-tokenizer php84-dom php84-xml php84-xmlreader \
        php84-xmlwriter php84-simplexml \
        php84-pecl-redis php84-pecl-memcached php84-pecl-rdkafka \
    # unversioned php + php-fpm on $PATH for composer / supervisord
    # (Alpine has no /usr/local/{bin,sbin} by default — create them first)
    && mkdir -p /usr/local/bin /usr/local/sbin \
    && ln -sf /usr/bin/php84      /usr/local/bin/php \
    && ln -sf /usr/sbin/php-fpm84 /usr/local/sbin/php-fpm \
    # apfd has no apk package — compile it via PECL with a THROWAWAY toolchain
    # (gcc/make/musl-dev + phpize/pecl), then drop it so the final image doesn't
    # ship a ~200 MB compiler. rdkafka/redis/memcached came from apk (own inis).
    # NB: the gcc unpack needs Docker disk headroom — if it throws an I/O error,
    # reclaim space first: `docker builder prune -af`.
    && apk add --no-cache --virtual .build-deps \
        php84-dev php84-pear gcc make musl-dev autoconf \
    && ln -sf /usr/bin/phpize84 /usr/local/bin/phpize \
    && ln -sf /usr/bin/php-config84 /usr/local/bin/php-config \
    && PECL="$(command -v pecl || command -v pecl84)" \
    && "$PECL" install apfd \
    && echo 'extension=apfd' > /etc/php84/conf.d/30_apfd.ini \
    && apk del .build-deps \
    && rm -f /usr/local/bin/phpize /usr/local/bin/php-config \
    # --- compat shims so the official-image configs/mounts work unchanged ---
    # 1) fpm pool already listens on 127.0.0.1:9000 (Alpine default); run it as
    #    the nginx web user instead of nobody so served apps can write
    && sed -ri 's#^user = .*#user = nginx#; s#^group = .*#group = nginx#' \
        /etc/php84/php-fpm.d/www.conf \
    # 2) /usr/local/etc/php/conf.d -> Alpine's conf.d (where the compose php
    #    service mounts php.ini / opcache.ini)
    && mkdir -p /usr/local/etc/php \
    && ln -sfn /etc/php84/conf.d /usr/local/etc/php/conf.d \
    # 3) nginx: server{} configs live in conf.d by repo convention. Alpine
    #    includes server blocks from http.d (http context) and conf.d from the
    #    MAIN context (wrong for server{}). Drop the main-context conf.d include,
    #    remove Alpine's default site, and make conf.d == http.d.
    && sed -i '\|include /etc/nginx/conf.d/\*.conf;|d' /etc/nginx/nginx.conf \
    && rm -f /etc/nginx/http.d/default.conf \
    && ln -sfn /etc/nginx/http.d /etc/nginx/conf.d \
    && mkdir -p /run/nginx /run/php /etc/supervisor/conf.d

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# supercronic — container-friendly cron, run as the [program:cron] supervisord
# program (off unless ENABLE_CRON=true). Vendored static binary (amd64, runs on
# musl) from assets/, COPYed at build time. Built from the repo root.
COPY assets/supersonic/v0.2.46/supercronic-linux-amd64 /usr/local/bin/supercronic
RUN chmod +x /usr/local/bin/supercronic

COPY configs/php-app/supervisord.conf /etc/supervisor/supervisord.conf
COPY configs/php-app/nginx.conf       /etc/nginx/conf.d/default.conf

WORKDIR /var/www/html

# Universal program switches (per-project conf.d files add more, e.g. queue).
ENV ENABLE_PHP=true \
    ENABLE_NGINX=true \
    ENABLE_CRON=false

EXPOSE 80
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
