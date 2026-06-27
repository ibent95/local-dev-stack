# =============================================================================
# cron-template-shell — scheduled job (POSIX shell) via supercronic.
# CLOUD/default image (Kubernetes/Fleet builds this). supercronic is vendored
# (./bin/supercronic, dropped in by `lds new`) — no network at build.
# =============================================================================
FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
COPY bin/supercronic /usr/local/bin/supercronic
RUN chmod +x /usr/local/bin/supercronic
WORKDIR /app
COPY crontab job.sh ./
CMD ["supercronic", "/app/crontab"]
