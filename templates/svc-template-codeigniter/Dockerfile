# =============================================================================
# PHP web app on lds/php (php-fpm + nginx via supervisord, global configs).
# Uses the GLOBAL default nginx (docroot public/) + supervisord — no local
# config needed. dev = the base as-is; prod = + composer install of src/.
# =============================================================================
FROM lds/php:8.4 AS dev

FROM dev AS prod
COPY src/ /var/www/html/
RUN composer install --no-dev --optimize-autoloader --no-interaction
EXPOSE 80
