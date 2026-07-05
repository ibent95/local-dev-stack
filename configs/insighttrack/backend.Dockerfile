ARG NODE_VERSION=26.3
FROM lds/node-dev:${NODE_VERSION}

USER root
RUN apk add --no-cache curl tar

ARG INSIGHTTRACK_REF=91310fcd94ac2ab9d89ebb6018f3ecfec9c57254

WORKDIR /opt/insighttrack-src
RUN curl -fsSL "https://codeload.github.com/NishikantaRay/InsightTrack/tar.gz/${INSIGHTTRACK_REF}" -o source.tgz \
 && mkdir -p repo \
 && tar -xzf source.tgz -C repo --strip-components=1 \
 && cp -a repo/apps/analytics-api /app

WORKDIR /app
RUN npm ci --omit=dev \
 && npm cache clean --force

ENV NODE_ENV=production
ENV PORT=3001
ENV DUCKDB_PATH=/data/analytics.duckdb

EXPOSE 3001

CMD ["sh", "-lc", "node scripts/migrate.js && node scripts/init.js && node src/index.js"]
