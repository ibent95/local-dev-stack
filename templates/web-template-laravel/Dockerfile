# =============================================================================
# Laravel full-stack on lds/php (php-fpm + nginx via supervisord, global
# configs). Adds Node (Vite) + queue/scheduler/vite programs, each env-toggled.
# =============================================================================
FROM lds/php:8.4
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*
COPY configs/worker.conf /etc/supervisor/conf.d/worker.conf
ENV ENABLE_QUEUE=false \
    ENABLE_SCHEDULER=false \
    ENABLE_VITE=false
EXPOSE 80
