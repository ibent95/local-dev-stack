# =============================================================================
# LDS Analytics UI — Nuxt/Vue + Tailwind + Recharts dashboard
# =============================================================================
ARG NODE_VERSION=26.3
FROM lds/node-dev:${NODE_VERSION}

USER root
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --ignore-scripts --legacy-peer-deps && npm rebuild

COPY . .

EXPOSE 4173
CMD ["npm", "run", "dev"]
