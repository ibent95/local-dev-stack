# =============================================================================
# LDS Analytics UI — Nuxt 4 production build
# =============================================================================
ARG NODE_VERSION=26.3

# Stage 1: Build Nuxt app
FROM lds/node-dev:${NODE_VERSION} AS builder
WORKDIR /app

COPY package.json ./
RUN npm install --ignore-scripts

ENV API_URL=http://analytics-api:3001
COPY . .

# Nuxt build outputs to .output/
RUN npm run build

# Stage 2: Production server (lighter — only needs the built output)
FROM lds/node-dev:${NODE_VERSION}
WORKDIR /app

# Copy the built output (includes all server code + dependencies)
COPY --from=builder /app/.output ./.output

# Set Nuxt nitro port to match exposed port
ENV PORT=4173
ENV HOSTNAME=0.0.0.0
ENV API_URL=http://analytics-api:3001

# Expose port
EXPOSE 4173

# Healthcheck
HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=12 \
  CMD wget -qO- http://127.0.0.1:4173/ >/dev/null 2>&1 || exit 1

# Start Nuxt production server on the correct port
CMD ["node", ".output/server/index.mjs"]