# =============================================================================
# Laravel API on lds/php (php-fpm + nginx via supervisord, global configs).
# Adds queue + scheduler programs (configs/worker.conf), each env-toggled.
# =============================================================================
FROM lds/php:8.4
COPY configs/worker.conf /etc/supervisor/conf.d/worker.conf
ENV ENABLE_QUEUE=false \
    ENABLE_SCHEDULER=false
EXPOSE 80
