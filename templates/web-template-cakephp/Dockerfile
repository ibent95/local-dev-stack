# =============================================================================
# CakePHP on lds/php — overrides the global nginx vhost (docroot webroot/).
# =============================================================================
FROM lds/php:8.4 AS dev
COPY configs/nginx.conf /etc/nginx/conf.d/default.conf

FROM dev AS prod
COPY src/ /var/www/html/
RUN composer install --no-dev --optimize-autoloader --no-interaction
EXPOSE 80
