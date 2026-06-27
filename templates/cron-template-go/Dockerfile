# =============================================================================
# cron-template-go — scheduled job (Go) via supercronic. CLOUD/default image.
# Compiled: build stage produces a binary, supercronic runs it. supercronic is
# vendored (./bin/supercronic) — no network at build.
# =============================================================================
FROM golang:1.25-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY job.go ./
RUN CGO_ENABLED=0 go build -o /out/job .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
COPY bin/supercronic /usr/local/bin/supercronic
RUN chmod +x /usr/local/bin/supercronic
WORKDIR /app
COPY --from=build /out/job /app/job
COPY crontab ./
CMD ["supercronic", "/app/crontab"]
