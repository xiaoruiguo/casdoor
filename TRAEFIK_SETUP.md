# Traefik API 网关设置指南

## 简介

本文档介绍如何在 Casdoor 前端和后端之间集成 Traefik API 网关，以提高系统的安全性、可靠性和可扩展性。

## 配置步骤

### 1. 环境准备

1. **安装 Docker 和 Docker Compose**
   - 确保你的系统已安装 Docker 和 Docker Compose

2. **配置环境变量**
   - 复制 `.env.example` 文件为 `.env`
   - 根据你的环境修改 `.env` 文件中的配置

### 2. 启动服务

使用 Docker Compose 启动服务：

```bash
docker-compose up -d
```

这将启动以下服务：
- Casdoor 后端 (8000 端口)
- MySQL 数据库 (3306 端口)
- Traefik API 网关 (80, 443, 8080 端口)

### 3. 访问服务

- **前端访问**：`https://localhost`
- **API 访问**：`https://api.localhost/api`
- **Traefik 仪表盘**：`http://localhost:8080`

### 4. 配置说明

#### Traefik 配置文件

- `traefik_casdoor_config.yaml`：Traefik 的主配置文件，包含路由规则、中间件配置等

#### 环境变量

- `CASDOOR_HOST`：Casdoor 的域名
- `YOUR_CLIENT_ID`：OIDC 客户端 ID
- `YOUR_CLIENT_SECRET`：OIDC 客户端密钥
- `YOUR_SESSION_SECRET`：会话密钥

### 5. 中间件功能

Traefik 配置了以下中间件：

- **认证中间件**：OIDC 认证
- **CORS 中间件**：跨域资源共享
- **限流中间件**：防止 API 滥用
- **安全头中间件**：增强安全性
- **压缩中间件**：提高传输效率
- **断路器中间件**：提高系统稳定性
- **重试中间件**：提高请求成功率

### 6. 健康检查

Casdoor 后端提供了健康检查端点：`/api/health`，Traefik 会定期检查此端点以确保服务健康。

### 7. 监控与日志

- **Prometheus 监控**：`https://api.localhost/metrics`
- **Traefik 日志**：存储在 `./traefik/logs` 目录

## 故障排除

### 1. 服务无法启动

- 检查 Docker Compose 日志：`docker-compose logs`
- 确保端口 80、443、8080、3306 未被占用

### 2. 前端无法访问后端 API

- 检查 Traefik 路由配置
- 确认 Casdoor 后端服务正常运行
- 检查网络连接

### 3. 认证失败

- 确保 OIDC 客户端配置正确
- 检查回调 URL 是否与 Traefik 配置一致

## 进阶配置

### 1. 自定义域名

- 修改 `.env` 文件中的 `CASDOOR_HOST` 为你的自定义域名
- 配置 DNS 记录指向你的服务器
- 确保 Traefik 的 Let's Encrypt 配置正确

### 2. 负载均衡

- 在 `traefik_casdoor_config.yaml` 中添加多个后端服务器
- 配置负载均衡策略

### 3. 安全增强

- 配置更严格的 TLS 选项
- 添加 WAF 中间件
- 配置 IP 白名单

## 总结

通过集成 Traefik API 网关，Casdoor 系统获得了以下好处：

- **提高安全性**：HTTPS、安全头、认证中间件
- **增强可靠性**：健康检查、断路器、重试机制
- **提升性能**：压缩、负载均衡
- **简化配置**：统一的路由管理
- **易于扩展**：动态配置、服务发现

Traefik 作为一个现代化的 API 网关，为 Casdoor 系统提供了强大的流量管理和安全保障。