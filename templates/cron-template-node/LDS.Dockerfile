# LOCAL dev image — uses the shared lds/node-dev base (run `lds build-bases`).
# Source bind-mounted (edit job.js -> next run uses it). Deploy uses ./Dockerfile.
FROM lds/node-dev:22
# supercronic ships in the lds/node-dev base image (no COPY needed).
WORKDIR /app
# Deps still install at build:  COPY package*.json ./ && RUN npm ci --omit=dev
CMD ["supercronic", "/app/crontab"]
