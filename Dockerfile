# ============================================================
# Claude Code Router — Docker 镜像
# 遵循 Node.js 官方 Docker 最佳实践 (https://github.com/nodejs/docker-node)
# 以服务模式运行（非桌面应用），不使用 Electron
# ============================================================
ARG NODE_VERSION=22

# ============================================================
# 构建阶段 — 需要完整工具链编译 native addons
FROM node:${NODE_VERSION}-bookworm AS builder

WORKDIR /build

# 先复制依赖 manifest，利用 Docker layer 缓存
COPY package*.json .npmrc ./
RUN npm ci && npm cache clean --force

# 复制源码并构建
COPY . .
RUN npm run build:assets

# ============================================================
# 运行阶段 — 最小基础镜像，不包含 npm/yarn
FROM debian:bookworm-slim AS runtime

LABEL org.opencontainers.image.title="Claude Code Router" \
      org.opencontainers.image.description="Local LLM gateway for Claude Code, Codex, ZCode — headless server mode" \
      org.opencontainers.image.license="MIT" \
      org.opencontainers.image.source="https://github.com/winffychu/claude-code-router"

# 1. 安装运行时系统依赖
#    dumb-init     → Node.js 不适合作为 PID 1，dumb-init 正确处理信号转发
#    ca-certificates → 网关需要 HTTPS 调用外部 API
RUN apt-get update && apt-get install -y --no-install-recommends \
    dumb-init \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 2. 创建非 root 用户（最小权限原则）
RUN groupadd --gid 1000 node \
    && useradd --uid 1000 --gid node --shell /bin/bash --create-home node

WORKDIR /app

# 3. 从 builder 复制 Node.js 运行时二进制（不含 npm/yarn → 更小更安全）
COPY --from=builder /usr/local/bin/node /usr/local/bin/

# 4. 复制编译产物和依赖
#    注意：better-sqlite3 的 native .node 文件包含在 node_modules 中
COPY --chown=node:node --from=builder /build/node_modules ./node_modules
COPY --chown=node:node --from=builder /build/dist ./dist
COPY --chown=node:node --from=builder /build/package.json ./

# 5. 创建持久化数据目录
RUN mkdir -p /home/node/.claude-code-router \
    && chown node:node /home/node/.claude-code-router

# 端口说明：
#   3456 - CCR Wrapper Gateway（Agent 连接端点）
#   3457 - Core Gateway Runtime（内部路由引擎）
#   3458 - Web 管理 UI
EXPOSE 3456 3457 3458

# 数据持久化（SQLite 配置、API Keys、用量日志等）
VOLUME ["/home/node/.claude-code-router"]

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://127.0.0.1:3458/health',(r)=>{process.exit(r.statusCode===200?0:1)}).on('error',()=>process.exit(1))"

# 切换到非 root 用户
USER node

# dumb-init 确保信号正确转发到 Node.js 进程
ENTRYPOINT ["dumb-init", "node", "dist/main/cli.js", "serve", "--host", "0.0.0.0"]
