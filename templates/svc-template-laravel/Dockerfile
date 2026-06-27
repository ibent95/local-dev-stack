# =============================================================================
# Laravel API on lds/php (php-fpm + nginx via supervisord, global configs).
# Adds queue + scheduler programs (configs/worker.conf), each env-toggled.
# =============================================================================
FROM lds/php:8.4 AS dev
COPY configs/worker.conf /etc/supervisor/conf.d/worker.conf
ENV ENABLE_QUEUE=false \
    ENABLE_SCHEDULER=false

FROM dev AS prod
COPY src/ /var/www/html/
RUN composer install --no-dev --optimize-autoloader --no-interaction
EXPOSE 80
