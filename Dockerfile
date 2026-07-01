# ============================================================
# Claude Code Router - Docker 镜像
# 以服务模式运行（非桌面应用）
# ============================================================
# 构建阶段
FROM node:22-bookworm AS builder

WORKDIR /app

# 缓存 package.json/package-lock.json 层
COPY package*.json ./
RUN npm ci

# 复制源码并构建
COPY . .
RUN npm run build:assets

# ============================================================
# 运行阶段
FROM node:22-bookworm-slim AS runtime

# 安装 better-sqlite3 运行时需要的系统库
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 只复制运行时需要的文件
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist

# 创建数据目录
RUN mkdir -p /root/.claude-code-router

# 默认端口：
#   3456 - CCR Wrapper Gateway
#   3457 - Core Gateway Runtime
#   3458 - Web Management UI
EXPOSE 3456 3457 3458

# 数据持久化（SQLite 配置、API Keys、用量日志等）
VOLUME ["/root/.claude-code-router"]

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://127.0.0.1:3458/health', (r) => {process.exit(r.statusCode===200?0:1)}).on('error',()=>process.exit(1))"

# 入口：启动 CCR Web Management Server（自动启动 Gateway）
ENTRYPOINT ["node", "dist/main/cli.js", "serve", "--host", "0.0.0.0"]
