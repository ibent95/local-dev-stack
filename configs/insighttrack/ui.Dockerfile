ARG NODE_VERSION=26.3
FROM lds/node-dev:${NODE_VERSION} AS builder

USER root
RUN apk add --no-cache curl tar

ARG INSIGHTTRACK_REF=91310fcd94ac2ab9d89ebb6018f3ecfec9c57254
ARG VITE_API_URL=/api

WORKDIR /opt/insighttrack-src
RUN curl -fsSL "https://codeload.github.com/NishikantaRay/InsightTrack/tar.gz/${INSIGHTTRACK_REF}" -o source.tgz \
 && mkdir -p repo \
 && tar -xzf source.tgz -C repo --strip-components=1

WORKDIR /opt/insighttrack-src/repo/apps/dashboard-web
RUN npm ci
ENV VITE_API_URL=${VITE_API_URL}
RUN npm run build

ARG NGINX_VERSION=1.27-alpine
FROM nginx:${NGINX_VERSION}

COPY configs/insighttrack/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /opt/insighttrack-src/repo/apps/dashboard-web/dist /usr/share/nginx/html

EXPOSE 4173

CMD ["nginx", "-g", "daemon off;"]
