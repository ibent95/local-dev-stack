# =============================================================================
# LDS Wiki API — Hono + Drizzle + PostgreSQL (production build)
# =============================================================================
ARG NODE_VERSION=26.3

FROM lds/node-dev:${NODE_VERSION} AS builder
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM lds/node-dev:${NODE_VERSION}
WORKDIR /app

ENV NODE_ENV=production

COPY package.json package-lock.json* ./
RUN npm install --omit=dev --ignore-scripts && npm cache clean --force

COPY --from=builder /app/dist ./dist

EXPOSE 3003

HEALTHCHECK --interval=15s --timeout=5s --start-period=15s --retries=12 \
  CMD wget -qO- http://127.0.0.1:3003/api/health >/dev/null 2>&1 || exit 1

CMD ["node", "dist/index.js"]