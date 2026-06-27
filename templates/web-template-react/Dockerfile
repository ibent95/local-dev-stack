# =============================================================================
# React SPA (Vite) — Node dev container with HMR.
#   dev  : vite dev server behind the proxy.
#   prod : build static files, serve with nginx.
# =============================================================================
FROM node:22-bookworm-slim AS dev
WORKDIR /app
EXPOSE 5173
CMD ["sh", "-c", "npm install && npm run dev -- --host 0.0.0.0 --port 5173"]

# --- builder ---
FROM node:22-bookworm-slim AS builder
WORKDIR /app
COPY src/ ./
RUN npm ci && npm run build

# --- prod (static files via nginx) ---
FROM nginx:1.27-alpine AS prod
COPY --from=builder /app/dist/ /usr/share/nginx/html/
EXPOSE 80
