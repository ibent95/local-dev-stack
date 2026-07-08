# =============================================================================
# LDS Tasks UI — Angular 22 production build with static nginx serving
# =============================================================================
ARG NODE_VERSION=26.3
ARG NGINX_VERSION=1.30
# Stage 1: Build the Angular app
FROM lds/node-dev:${NODE_VERSION} AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --ignore-scripts
COPY . .
RUN npm run build

# Stage 2: Production nginx serving
FROM lds/nginx:${NGINX_VERSION}
LABEL maintainer="lds"

# Copy built static files
COPY --from=builder /app/dist/tasks-ui/browser /usr/share/nginx/html

# Copy custom nginx config (optional - can use default)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 4174

# CMD inherited from lds/nginx base (runs nginx in foreground)
# Note: lds/nginx is DHI-hardened (no shell/wget). Health is verified at proxy layer.