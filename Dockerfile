# ============================================================
# Claude Code Router — Docker 镜像
# Base: gcr.io/distroless/nodejs22-debian13:nonroot
# 零 shell/包管理器，最小攻击面，~130MB
# ============================================================
ARG NODE_VERSION=22

# ============================================================
# Stage 0: tini — 静态编译的 init 系统（PID 1 信号处理）
FROM krallin/tini:latest AS tini

# ============================================================
# Stage 1: builder — 完整工具链，构建应用 + native addons
FROM node:${NODE_VERSION}-bookworm AS builder

WORKDIR /build

# 缓存 npm 依赖层
COPY package*.json .npmrc ./
RUN npm ci && npm cache clean --force

# 源码构建
COPY . .
RUN npm run build:assets

# 预创建数据目录，设好权限（供 runtime COPY --chown）
RUN mkdir -p /data/claude-code-router && chown -R 65532:65532 /data

# ============================================================
# Stage 2: runtime — Distroless Node.js 22，nonroot 用户
FROM gcr.io/distroless/nodejs22-debian13:nonroot

LABEL org.opencontainers.image.title="Claude Code Router" \
      org.opencontainers.image.description="Local LLM gateway — headless server mode (distroless)" \
      org.opencontainers.image.license="MIT" \
      org.opencontainers.image.source="https://github.com/winffychu/claude-code-router"

WORKDIR /app

# 复制运行时文件
COPY --from=builder /build/node_modules ./node_modules
COPY --from=builder /build/dist ./dist
COPY --from=builder /build/package.json ./
COPY --from=tini /tini /usr/local/bin/tini

# 预建数据目录（nonroot uid=65532 可写）
COPY --from=builder --chown=65532:65532 /data /home/nonroot/.claude-code-router

# 端口说明：
#   3456 - CCR Wrapper Gateway（Agent 连接端点）
#   3457 - Core Gateway Runtime（内部路由引擎）
#   3458 - Web 管理 UI
EXPOSE 3456 3457 3458

VOLUME ["/home/nonroot/.claude-code-router"]

# 健康检查（distroless 无 shell，必须 exec 形式）
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/nodejs/bin/node", "-e", "require('http').get('http://127.0.0.1:3458/health',(r)=>{process.exit(r.statusCode===200?0:1)}).on('error',()=>process.exit(1))"]

# tini 作为 PID 1，非 root 用户由 base image 提供（uid=65532）
ENTRYPOINT ["/usr/local/bin/tini", "--", "/nodejs/bin/node", "dist/main/cli.js", "serve", "--host", "0.0.0.0"]
