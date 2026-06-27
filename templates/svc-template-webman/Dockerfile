# =============================================================================
# Webman (workerman) — a long-running PHP HTTP server (NOT php-fpm), so no nginx.
# Based on lds/php; adds pcntl which workerman needs. Listens on :8787.
# =============================================================================
FROM lds/php:8.4 AS dev
RUN docker-php-ext-install pcntl
WORKDIR /app
CMD ["php", "start.php", "start"]

FROM dev AS prod
COPY src/ /app/
RUN composer install --no-dev --optimize-autoloader --no-interaction
EXPOSE 8787
CMD ["php", "start.php", "start"]
