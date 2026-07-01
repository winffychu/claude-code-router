# Claude Code Router — Docker 部署指南（Distroless）

通过 Docker 将 CCR 以后台服务方式运行，无需桌面应用。

> **基础镜像**：`gcr.io/distroless/nodejs22-debian13:nonroot`
> 零 shell/包管理器，仅包含 Node.js 22 + 应用本身，镜像约 **130MB**。

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
  -v ccr-data:/home/nonroot/.claude-code-router \
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
| `NODE_ENV` | Node 环境 | production |

### 端口映射

| 容器端口 | 用途 |
|---------|------|
| 3456 | CCR Wrapper Gateway（Agent 连接端点） |
| 3457 | Core Gateway Runtime |
| 3458 | Web 管理 UI |

## 数据持久化

所有数据（SQLite 配置数据库、API Keys、用量日志、请求日志）都存储在 `~/.claude-code-router/` 目录下（容器内为 `/home/nonroot/.claude-code-router/`）。通过 Docker volume 持久化：

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

## 调试

Distroless 镜像不含 shell。如需排查问题，将 `Dockerfile` 末尾的 `:nonroot` 替换为 `:debug-nonroot` 重新构建，即可获取带 busybox 的调试镜像：

```dockerfile
FROM gcr.io/distroless/nodejs22-debian13:debug-nonroot
```

然后：

```bash
docker run --entrypoint=sh -ti claude-code-router
```

## 更新

```bash
git pull
docker build -t claude-code-router .
docker compose up -d
```

## 日志

```bash
docker logs -f ccr
docker logs --tail 100 ccr
```

## 架构说明

```
PID 1: tini（信号转发）
  └── /nodejs/bin/node dist/main/cli.js serve --host 0.0.0.0
        ├── Web Management UI (:3458)
        ├── CCR Wrapper Gateway (:3456)
        └── Core Gateway Runtime (:3457)
```

## 安全基线

| 措施 | 说明 |
|------|------|
| 基础镜像 | Distroless Node.js 22，零 shell/包管理器 |
| 攻击面 | ~130MB，仅含 Node.js + 业务代码 + 必需系统库 |
| 运行用户 | 非 root（uid=65532） |
| PID 1 | tini 管理信号转发，防止僵尸进程 |
| CVE 扫描 | 信号噪点极低，仅需关注 Node.js 和业务依赖 |
| 只读加固 | 可添加 `--read-only --tmpfs /tmp` |
