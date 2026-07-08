# =============================================================================
# LDS Wiki UI — Next.js 16 production build (standalone output)
# =============================================================================
ARG NODE_VERSION=26.3

# Stage 1: Build Next.js app
FROM lds/node-dev:${NODE_VERSION} AS builder
WORKDIR /app

COPY package.json ./
RUN npm install

ENV API_URL=http://wiki-api:3003
COPY . .
RUN npm run build

# Stage 2: Production server
FROM lds/node-dev:${NODE_VERSION}
WORKDIR /app

ENV PORT=4175
ENV HOSTNAME=0.0.0.0
ENV API_URL=http://wiki-api:3003

# Copy standalone server bundle (includes its own node_modules)
COPY --from=builder /app/.next/standalone ./

# Copy static assets that standalone server expects as sibling dirs
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

# Expose port
EXPOSE 4175

# Healthcheck
HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=12 \
  CMD wget -qO- http://127.0.0.1:4175/ >/dev/null 2>&1 || exit 1

# Start the standalone server
CMD ["node", "server.js"]