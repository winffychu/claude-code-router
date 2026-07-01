# =============================================================
# Stage 1: Build — Node.js native addons (esbuild → 平台无关 JS)
# =============================================================
FROM node:22-bookworm AS builder

WORKDIR /build

COPY package*.json .npmrc ./
RUN npm ci && npm cache clean --force

COPY . .
RUN npm run build:assets

RUN mkdir -p /data/claude-code-router && chown -R 65532:65532 /data

# =============================================================
# Stage 2: distroless — 生产推荐
#   Node.js 22 runtime, 非 root, 零 shell/包管理器, ~130MB
# =============================================================
FROM gcr.io/distroless/nodejs22-debian13:nonroot

LABEL org.opencontainers.image.title="Claude Code Router" \
      org.opencontainers.image.description="Local LLM gateway — headless server mode" \
      org.opencontainers.image.license="MIT" \
      org.opencontainers.image.source="https://github.com/winffychu/claude-code-router"

WORKDIR /app

COPY --from=builder /build/node_modules ./node_modules
COPY --from=builder /build/dist ./dist
COPY --from=builder /build/package.json ./
COPY --from=builder --chown=65532:65532 /data /home/nonroot/.claude-code-router

EXPOSE 3456 3457 3458

VOLUME ["/home/nonroot/.claude-code-router"]

ENTRYPOINT ["/nodejs/bin/node", "dist/main/cli.js", "serve", "--host", "0.0.0.0"]
