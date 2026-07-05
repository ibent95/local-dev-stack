# =============================================================================
# Node.js web app — live reload via tsx watch, from the shared base lds/node-dev.
# =============================================================================
FROM lds/node-dev:22
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]
