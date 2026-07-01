# Claude Code Router — Docker 部署指南

通过 Docker 将 CCR 以后台服务方式运行，无需桌面应用。

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
  -v ccr-data:/root/.claude-code-router \
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
| `CCR_INTERNAL_HOME_DIR` | 覆盖家目录（影响数据路径） | 容器 home |
| `NODE_ENV` | Node 环境 | production |

### 端口映射

| 容器端口 | 用途 |
|---------|------|
| 3456 | CCR Wrapper Gateway（Agent 连接端点） |
| 3457 | Core Gateway Runtime |
| 3458 | Web 管理 UI |

## 数据持久化

所有数据（SQLite 配置数据库、API Keys、用量日志、请求日志）都存储在 `~/.claude-code-router/` 目录下。通过 Docker volume 持久化：

```bash
docker volume inspect ccr-data
```

删除容器不会丢失数据。如需重置，删除 volume 并重建：

```bash
docker compose down -v
docker compose up -d
```

## 健康检查

Dockerfile 已内置健康检查。查看容器状态：

```bash
docker ps --filter name=ccr
```

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
1. **Web Management Server**（Node.js）：提供 HTTP 管理界面和 RPC API
2. **CCR Wrapper Gateway**：Claude Code/Codex/ZCode 兼容的 API 网关端点
3. **Core Gateway Runtime**：底层代理/路由引擎

这三个服务都在同一个 Node.js 进程中运行，通过 `ccr serve` 命令启动。
