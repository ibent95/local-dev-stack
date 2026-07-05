# =============================================================================
# Angular SPA — Node dev container (ng serve / HMR).
# =============================================================================
FROM lds/node-dev:22
WORKDIR /app
EXPOSE 4200
# Deps install on first boot (node_modules lives in an anonymous volume).
CMD ["sh", "-c", "npm install && npx ng serve --host 0.0.0.0 --port 4200 --disable-host-check"]
