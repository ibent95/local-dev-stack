# =============================================================================
# cron-template-node — scheduled job (Node.js) via supercronic.
# CLOUD/default image. supercronic vendored (./bin/supercronic) — no network.
# =============================================================================
FROM node:22-alpine
RUN apk add --no-cache ca-certificates tzdata
COPY bin/supercronic /usr/local/bin/supercronic
RUN chmod +x /usr/local/bin/supercronic
WORKDIR /app
# Deps:  COPY package*.json ./ && RUN npm ci --omit=dev
COPY crontab job.js ./
CMD ["supercronic", "/app/crontab"]
