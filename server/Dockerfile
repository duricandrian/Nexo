FROM mirror.gcr.io/library/node:20-bookworm-slim AS build
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ && rm -rf /var/lib/apt/lists/*
COPY package*.json ./
RUN npm ci --omit=dev

FROM mirror.gcr.io/library/node:20-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production DATA_DIR=/data PORT=8080
COPY --from=build /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
RUN mkdir -p /data && chown node:node /data
USER node
VOLUME ["/data"]
EXPOSE 8080
CMD ["node", "src/index.js"]
