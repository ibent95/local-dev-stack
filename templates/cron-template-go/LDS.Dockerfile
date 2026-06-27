# LOCAL dev image (lds/docker-compose). Builds via the shared lds/go-dev base.
# Go is compiled, so there's no live-edit — `lds app restart` rebuilds.
# supercronic comes from the lds/go-dev base (copied into the alpine runtime).
FROM lds/go-dev:1.25 AS build
WORKDIR /src
COPY go.mod ./
COPY job.go ./
RUN CGO_ENABLED=0 go build -o /out/job .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
COPY --from=build /usr/local/bin/supercronic /usr/local/bin/supercronic
WORKDIR /app
COPY --from=build /out/job /app/job
COPY crontab ./
CMD ["supercronic", "/app/crontab"]
