# =============================================================================
# LDS Tasks API — Hono + Drizzle + PostgreSQL
# =============================================================================
ARG NODE_VERSION=26.3
FROM lds/node-dev:${NODE_VERSION}

USER root
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --ignore-scripts --legacy-peer-deps && npm rebuild

COPY . .

EXPOSE 3002
CMD ["npm", "run", "dev"]
