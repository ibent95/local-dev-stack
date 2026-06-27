# LOCAL dev image. There's no lds/* base for plain shell, so this uses alpine
# (the one cron tech without an LDS base). Source bind-mounted (edit job.sh ->
# next run uses it). supercronic vendored (./bin/supercronic). Deploy uses ./Dockerfile.
FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
COPY bin/supercronic /usr/local/bin/supercronic
RUN chmod +x /usr/local/bin/supercronic
WORKDIR /app
CMD ["supercronic", "/app/crontab"]
