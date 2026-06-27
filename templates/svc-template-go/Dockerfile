# =============================================================================
# dev  : live reload via air, from the shared base lds/go-dev.
# prod : tiny static binary on distroless.
# =============================================================================
FROM lds/go-dev:1.25 AS dev
WORKDIR /app
COPY go.mod ./
RUN go mod download || true
COPY . .
EXPOSE 8080
CMD ["air", "-c", ".air.toml"]

FROM golang:1.25-bookworm AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o /server .

FROM gcr.io/distroless/static-debian12 AS prod
COPY --from=builder /server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
