# Casdoor 前端通过 Traefik 网关配置指南

## 架构说明

```
浏览器 → http://localhost:7001 (前端 dev server)
              ↓ /api, /.well-known 等路径代理到
         http://127.0.0.1 (Traefik 网关 :80)
              ↓ 路由转发到
         Casdoor 后端 (:8080)
```

## 1. 配置前端环境变量

编辑 `web/.env`：

```
REACT_APP_API_URL=http://localhost
REACT_APP_FRONTEND_URL=http://localhost:7001
```

- `REACT_APP_API_URL`：前端 API 请求的基础 URL，编译时注入到 JS 中
- `REACT_APP_FRONTEND_URL`：前端自身访问地址

## 2. 配置开发代理（craco.config.js）

编辑 `web/craco.config.js`，将所有代理目标从 `http://localhost:8000`（直连后端）改为 `http://127.0.0.1`（Traefik 网关）：

```js
devServer: {
  proxy: {
    "/api": {
      target: "http://127.0.0.1",
      changeOrigin: true,
    },
    "/swagger": {
      target: "http://127.0.0.1",
      changeOrigin: true,
    },
    "/files": {
      target: "http://127.0.0.1",
      changeOrigin: true,
    },
    "/.well-known/openid-configuration": {
      target: "http://127.0.0.1",
      changeOrigin: true,
    },
    "/cas/**/serviceValidate": {
      target: "http://127.0.0.1",
      changeOrigin: true,
    },
    "/cas/**/proxyValidate": {
      target: "http://127.0.0.1",
      changeOrigin: true,
    },
    "/cas/**/proxy": {
      target: "http://127.0.0.1",
      changeOrigin: true,
    },
    "/cas/**/validate": {
      target: "http://127.0.0.1",
      changeOrigin: true,
    },
    "/cas/**/p3/serviceValidate": {
      target: "http://127.0.0.1",
      changeOrigin: true,
    },
    "/cas/**/p3/proxyValidate": {
      target: "http://127.0.0.1",
      changeOrigin: true,
    },
    "/scim": {
      target: "http://127.0.0.1",
      changeOrigin: true,
    },
  },
},
```

> **注意**：使用 `127.0.0.1` 而非 `localhost`，因为 Windows 下 craco 代理连接 `localhost` 时可能出现 504 超时问题。

## 3. 修改 ServerUrl 映射（Setting.js）

编辑 `web/src/Setting.js`，修改 `getFullServerUrl` 函数：

```js
export function getFullServerUrl() {
  let fullServerUrl = window.location.origin;
  if (fullServerUrl === "http://localhost:7001") {
    fullServerUrl = "http://localhost";  // 原值: "http://localhost:8000"
  }
  return fullServerUrl;
}
```

此函数在开发模式下（前端运行在 7001 端口）将 ServerUrl 指向 Traefik 网关而非直连后端。

## 4. 配置后端 origin

编辑 `conf/app.conf`，确保 origin 指向 Traefik 网关：

```ini
origin = "http://localhost"
originFrontend = "http://localhost"
```

这影响 OIDC 发现端点（`/.well-known/openid-configuration`）返回的 URL。

## 5. 编译前端（生产构建）

```bash
cd web
npm install
npm run build
```

构建流程：
1. `npm run build` → craco 构建到 `web/build-temp/`
2. `npm run postbuild` → `node mv.js` 将 `build-temp/` 重命名为 `build/`

构建产物在 `web/build/` 目录，Casdoor 后端通过 `frontendBaseDir = ./web/build` 提供静态文件服务。

## 6. 运行前端开发服务器

```bash
cd web
npm run start
```

前端开发服务器运行在 `http://localhost:7001`，API 请求通过代理转发到 Traefik 网关。

## 7. curl 测试验证

### 测试前端页面

```bash
# 前端主页
curl -s -o /dev/null -w "%{http_code}" http://localhost:7001/
# 预期: 200

# 登录页面
curl -s -o /dev/null -w "%{http_code}" http://localhost:7001/login
# 预期: 200
```

### 测试 API 代理（前端 → Traefik → 后端）

```bash
# API 代理
curl -s http://localhost:7001/api/applications
# 预期: {"status":"error","msg":"Unauthorized operation",...}（未登录属正常）

# OIDC 发现端点代理
curl -s http://localhost:7001/.well-known/openid-configuration
# 预期: issuer 为 "http://localhost" 的 JSON 响应
```

### 测试 Traefik 网关直连

```bash
# Traefik 前端
curl -s -o /dev/null -w "%{http_code}" http://localhost/
# 预期: 200

# Traefik API
curl -s -o /dev/null -w "%{http_code}" http://localhost/api/applications
# 预期: 200
```

### 测试后端直连

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/applications
# 预期: 200
```

## 8. 验证构建产物中的 API URL

```bash
node -e "const fs=require('fs');const c=fs.readFileSync('web/build/static/js/main.XXXXXXXX.js','utf8');const idx=c.indexOf('http://localhost');if(idx>=0){console.log('FOUND http://localhost');console.log(c.substring(Math.max(0,idx-50),idx+50))}else{console.log('NOT FOUND')}"
```

确认构建产物中 `ServerUrl="http://localhost"` 已正确注入。

## 关键配置文件汇总

| 文件 | 作用 | 关键配置 |
|------|------|----------|
| `web/.env` | 前端环境变量（编译时注入） | `REACT_APP_API_URL=http://localhost` |
| `web/craco.config.js` | 开发服务器代理配置 | `target: "http://127.0.0.1"` |
| `web/src/Setting.js` | 运行时 ServerUrl 映射 | `getFullServerUrl()` 中 7001 → localhost |
| `conf/app.conf` | 后端 origin 配置 | `origin = "http://localhost"` |

## 常见问题

### Q: 代理返回 504 Gateway Timeout

Windows 下 `localhost` 可能解析到 IPv6 地址，导致代理连接失败。解决方案：在 `craco.config.js` 中使用 `127.0.0.1` 替代 `localhost`。

### Q: OIDC 端点返回 `https://api.localhost`

后端进程使用了旧配置，需要重启后端使 `conf/app.conf` 中的 `origin` 配置生效。

### Q: 修改 .env 后构建产物中 API URL 未更新

`.env` 中的变量在编译时注入，必须重新执行 `npm run build` 才能生效。
