# Build Nakama TypeScript runtime module
FROM node:20-alpine AS server-builder
WORKDIR /app/server
COPY server/package.json server/package-lock.json ./
RUN npm ci
COPY server/tsconfig.json server/rollup.config.js ./
COPY server/src ./src
RUN npm run build

# Nakama game server
FROM registry.heroiclabs.com/heroiclabs/nakama:3.21.1
COPY --from=server-builder /app/server/build /nakama/data/modules
COPY docker/nakama-entrypoint.sh /nakama-entrypoint.sh
RUN chmod +x /nakama-entrypoint.sh

EXPOSE 7350

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=5 \
  CMD /nakama/nakama healthcheck || exit 1

ENTRYPOINT ["/nakama-entrypoint.sh"]
