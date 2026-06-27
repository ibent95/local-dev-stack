# =============================================================================
# Angular SPA — Node dev container (ng serve / HMR).
#   dev  : ng serve behind the proxy.
#   prod : build static files, serve with nginx.
# =============================================================================
FROM node:22-bookworm AS dev
WORKDIR /app
EXPOSE 4200
# Deps install on first boot (node_modules lives in an anonymous volume).
CMD ["sh", "-c", "npm install && npx ng serve --host 0.0.0.0 --port 4200 --disable-host-check"]

# --- builder ---
FROM node:22-bookworm AS builder
WORKDIR /app
COPY src/ ./
RUN npm ci && npm run build

# --- prod (static files via nginx) ---
FROM nginx:1.27-alpine AS prod
# Angular outputs to dist/<project>/browser in v17+ — adjust if needed.
COPY --from=builder /app/dist/ /usr/share/nginx/html/
EXPOSE 80
