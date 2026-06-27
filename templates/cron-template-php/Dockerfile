# =============================================================================
# cron-template-php — scheduled job (PHP CLI) via supercronic.
# CLOUD/default image. supercronic vendored (./bin/supercronic) — no network.
# =============================================================================
FROM php:8.4-cli-alpine
RUN apk add --no-cache ca-certificates tzdata
COPY bin/supercronic /usr/local/bin/supercronic
RUN chmod +x /usr/local/bin/supercronic
WORKDIR /app
COPY crontab job.php ./
CMD ["supercronic", "/app/crontab"]
