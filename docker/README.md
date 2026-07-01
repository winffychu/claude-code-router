# Claude Code Router — Docker 部署指南

通过 Docker 将 CCR 以后台服务方式运行，无需桌面应用。

> **构建原理**：采用多阶段构建，运行时基于 `debian:bookworm-slim`
> 最小基础镜像（不含 npm/yarn），仅从构建阶段复制 Node.js 二进制和编译产物。

## 快速开始

```bash
# 构建镜像
docker build -t claude-code-router .

# 启动容器
docker run -d \
  --name ccr \
  -p 3456:3456 \
  -p 3457:3457 \
  -p 3458:3458 \
  -v ccr-data:/home/node/.claude-code-router \
  --restart unless-stopped \
  claude-code-router
```

或者用 docker-compose：

```bash
docker compose up -d
```

## 访问

启动后：
- **Web 管理界面**：http://localhost:3458
- **CCR Wrapper Gateway**：http://localhost:3456（Claude Code/Codex/ZCode 连接用）
- **Core Gateway Runtime**：http://localhost:3457（内部使用）

首次访问 Web 管理界面，浏览器地址栏会带有一个 `ccr_web_token` 参数（自动认证令牌）。

## 配置

### 首次配置

1. 打开 `http://localhost:3458`
2. 添加 Provider，配置路由规则
3. 启动 Gateway（**Server > Start**）

配置持久化在 Docker volume `ccr-data` 中。重启容器后配置保留。

### 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `CCR_WEB_HOST` | Web 管理界面监听地址 | 0.0.0.0 |
| `CCR_WEB_PORT` | Web 管理界面监听端口 | 3458 |
| `CCR_INTERNAL_HOME_DIR` | 覆盖家目录（影响数据路径） | /home/node |
| `NODE_ENV` | Node 环境 | production |

### 端口映射

| 容器端口 | 用途 |
|---------|------|
| 3456 | CCR Wrapper Gateway（Agent 连接端点） |
| 3457 | Core Gateway Runtime |
| 3458 | Web 管理 UI |

## 数据持久化

所有数据（SQLite 配置数据库、API Keys、用量日志、请求日志）都存储在 `~/.claude-code-router/` 目录下（容器内为 `/home/node/.claude-code-router/`）。通过 Docker volume 持久化：

```bash
docker volume inspect ccr-data
```

删除容器不会丢失数据。如需重置，删除 volume 并重建：

```bash
docker compose down -v
docker compose up -d
```

## 健康检查

Docker 内置健康检查，每 30s 检测 `/health` 端点。查看容器状态：

```bash
docker ps --filter name=ccr
```

## 安全

- **非 root 用户**：容器内以 `node` 用户（uid 1000）运行，遵循最小权限原则
- **无包管理器**：运行时不包含 npm/yarn，减少攻击面
- **只读文件系统**：如需进一步加固，可添加 `--read-only` 并将 `/tmp` 挂载为 tmpfs

## 更新

```bash
# 拉取最新的源码
git pull

# 重新构建镜像
docker build -t claude-code-router .

# 重启容器
docker compose up -d
```

## 日志

```bash
# 查看实时日志
docker logs -f ccr

# 查看最近 N 行
docker logs --tail 100 ccr
```

## 架构说明

CCR 容器运行时包含以下进程：
1. **dumb-init** — PID 1，处理 SIGTERM/SIGINT 信号并正确转发给子进程
2. **Node.js 进程** — 包含 Web Management Server、CCR Wrapper Gateway、Core Gateway Runtime

```
PID 1: dumb-init
  └── node dist/main/cli.js serve --host 0.0.0.0
        ├── Web Management UI (:3458)
        ├── CCR Wrapper Gateway (:3456)
        └── Core Gateway Runtime (:3457)
```

## 优化说明

Dockerfile 遵循 [Node.js 官方 Docker 最佳实践](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md)：

| 实践 | 实现 |
|------|------|
| 多阶段构建 | builder → runtime，builder 编译 native addons，runtime 只跑代码 |
| 最小基础镜像 | 运行时使用 `debian:bookworm-slim`，不包含 npm/yarn |
| PID 1 信号处理 | `dumb-init` 正确转发 SIGTERM/SIGINT 到 Node.js |
| 非 root 用户 | `USER node`（uid=1000）最小权限运行 |
| 层缓存优化 | package.json 先于源码复制 |
| 编译依赖隔离 | node-gyp 工具链只在 builder 阶段存在 |
| 健康检查 | 通过 `/health` 端点检测 |
| 原生模块兼容 | 使用 glibc（bookworm）确保 better-sqlite3 等 native addon 稳定运行 |
