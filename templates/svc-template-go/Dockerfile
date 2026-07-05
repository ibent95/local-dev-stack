# =============================================================================
# Go API — live reload via air, from the shared base lds/go-dev.
# =============================================================================
FROM lds/go-dev:1.25
WORKDIR /app
COPY go.mod ./
RUN go mod download || true
COPY . .
EXPOSE 8080
CMD ["air", "-c", ".air.toml"]
