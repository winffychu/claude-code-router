# =============================================================
# Stage 1: Build — Node.js native addons (esbuild → 平台无关 JS)
# =============================================================
FROM node:22-bookworm AS builder

WORKDIR /build

COPY package*.json .npmrc ./
RUN npm ci && npm cache clean --force

COPY . .
RUN npm run build:assets

# =============================================================
# Stage 2: distroless — 生产推荐
#   Node.js 22 runtime, 非 root, 零 shell/包管理器, ~130MB
# =============================================================
FROM gcr.io/distroless/nodejs22-debian13:nonroot

LABEL org.opencontainers.image.title="Claude Code Router" \
      org.opencontainers.image.description="Local LLM gateway — headless server mode" \
      org.opencontainers.image.license="MIT" \
      org.opencontainers.image.source="https://github.com/winffychu/claude-code-router"

ENV HOME=/app

WORKDIR /app

# COPY --chown=65532:65532 确保 nonroot 用户能写数据目录
COPY --from=builder --chown=65532:65532 /build/node_modules ./node_modules
COPY --from=builder --chown=65532:65532 /build/dist ./dist
COPY --from=builder --chown=65532:65532 /build/package.json ./

EXPOSE 3456 3457 3458

ENTRYPOINT ["/nodejs/bin/node", "dist/main/cli.js", "serve", "--host", "0.0.0.0"]
