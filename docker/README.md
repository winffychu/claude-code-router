# Claude Code Router — Docker 部署指南

通过 Docker 将 CCR 以后台服务方式运行，无需桌面应用。

**基础镜像**：`gcr.io/distroless/nodejs22-debian13:nonroot`  
Node.js 22 runtime，非 root 运行，零 shell/包管理器，镜像约 **130MB**。

## 快速开始

```bash
docker build -t claude-code-router .
docker compose up -d
```

或者手动：

```bash
docker run -d \
  --name ccr \
  -p 3456:3456 -p 3457:3457 -p 3458:3458 \
  -v ccr-data:/home/nonroot/.claude-code-router \
  --restart unless-stopped \
  claude-code-router
```

## 端口

| 端口 | 用途 |
|------|------|
| 3456 | CCR Wrapper Gateway（Agent 连接端点） |
| 3457 | Core Gateway Runtime（内部路由引擎） |
| 3458 | Web 管理 UI |

## 数据持久化

配置/日志存储在 Docker volume `ccr-data`（映射到容器 `/home/nonroot/.claude-code-router/`）：

```bash
docker volume inspect ccr-data
docker compose down -v   # 重置
```

## 调试

如需 shell 排查，改用 `:debug-nonroot` 构建：

```dockerfile
FROM gcr.io/distroless/nodejs22-debian13:debug-nonroot
```

```bash
docker run --entrypoint=sh -ti claude-code-router
```
