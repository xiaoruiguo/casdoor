# Casdoor 技术栈与代码结构分析

## 一、项目概述

Casdoor 是一个开源的 AI 优先身份与访问管理（IAM）/ AI MCP 网关和认证服务器，提供 Web UI 管理界面，支持 MCP、A2A、OAuth 2.1、OIDC、SAML、CAS、LDAP、SCIM、WebAuthn、TOTP、MFA、Face ID、Google Workspace、Azure AD 等多种协议和集成。

- **项目地址**: `github.com/casdoor/casdoor`
- **许可证**: Apache 2.0
- **Go 版本**: 1.25.0+（toolchain go1.25.8）

---

## 二、后端技术栈

### 2.1 核心框架

| 技术 | 版本 | 用途 |
|------|------|------|
| **Go** | 1.25.0+ | 后端主语言 |
| **Beego** | v2.3.8 | Web 框架（路由、控制器、Session、配置） |
| **Xorm** | v1.1.6 | ORM 框架（数据库操作） |
| **Casbin** | v2.77.2 | 权限控制（RBAC/ABAC 策略引擎） |

### 2.2 数据库支持

| 数据库 | 驱动包 | 说明 |
|--------|--------|------|
| **MySQL** | `github.com/go-sql-driver/mysql` v1.8.1 | 默认推荐 |
| **PostgreSQL** | `github.com/lib/pq` v1.10.9 | 完整支持 |
| **SQLite** | `modernc.org/sqlite` v1.18.2 | 开发/轻量部署 |
| **MSSQL** | `github.com/microsoft/go-mssqldb` v1.9.0 | 企业场景 |

默认配置使用 SQLite（`casdoor.db`），生产环境推荐 MySQL/PostgreSQL。

### 2.3 认证与安全

| 技术 | 版本 | 用途 |
|------|------|------|
| **JWT** | `github.com/golang-jwt/jwt/v5` v5.3.0 | Token 签发与验证 |
| **go-jose** | v4.1.3 | JOSE 标准（JWS/JWE/JWK） |
| **jwx** | v1.2.29 | JWT/JWK 处理 |
| **WebAuthn** | `github.com/go-webauthn/webauthn` v0.10.2 | FIDO2 无密码认证 |
| **OTP** | `github.com/pquerna/otp` v1.4.0 | TOTP/HOTP 多因子认证 |
| **Argon2id** | `github.com/alexedwards/argon2id` | 密码哈希 |
| **Kerberos** | `github.com/jcmturner/gokrb5/v8` v8.4.4 | Kerberos 认证 |
| **OAuth2** | `golang.org/x/oauth2` v0.34.0 | OAuth2 客户端 |
| **Crypto** | `golang.org/x/crypto` v0.47.0 | 加密工具库 |

### 2.4 身份提供商（IdP）集成

| 类别 | 支持的提供商 |
|------|-------------|
| **社交登录** | GitHub, GitLab, Google, Facebook, LinkedIn, Twitter, WeChat, QQ, Weibo, Bilibili, Douyin, DingTalk, Lark, Telegram, Okta, ADFS, Alipay, Baidu, Gitee, Kwai, Infoflow |
| **企业 IdP** | Azure AD, Azure AD B2C, Google Workspace, Keycloak, Okta |
| **Web3** | MetaMask, Coinbase, Frontier, Gnosis, Phantom, Sequence, Taho, Trust |
| **通用 OAuth** | 通过 `markbates/goth` 支持更多提供商 |

### 2.5 通知与消息

| 类型 | 技术 |
|------|------|
| **邮件** | SMTP, SendGrid, Resend, Azure ACS, Custom HTTP |
| **短信** | 阿里云, 腾讯云, Volcengine, Twilio, Custom HTTP, UniSMS |
| **通知** | Slack, Discord, Telegram, Lark, DingTalk, WeCom, Microsoft Teams, Google Chat, Matrix, Line, Viber, Pushover, Pushbullet, Reddit, Rocket.Chat, WebPush, Bark, CuCloud |

### 2.6 支付集成

| 技术 | 说明 |
|------|------|
| **Stripe** | v74.29.0 |
| **PayPal** | 通过 go-pay |
| **Alipay** | 通过 go-pay |
| **WeChat Pay** | 通过 go-pay |
| **Paddle** | v1.0.0 |
| **LemonSqueezy** | v1.2.4 |
| **Adyen** | v11.0.0 |
| **Airwallex** | 内置 |
| **Polar** | v0.12.0 |
| **FastSpring** | 内置 |
| **Dummy** | 测试用 |

### 2.7 对象存储

| 提供商 | 包 |
|--------|-----|
| **AWS S3** | `aws-sdk-go-v2/service/s3` |
| **阿里云 OSS** | `aliyun-oss-go-sdk` |
| **腾讯云 COS** | `tencentcloud-sdk-go` |
| **Azure Blob** | `azure-storage-blob-go` |
| **Google Cloud** | `cloud.google.com/go/storage` |
| **MinIO** | 基于 S3 兼容 |
| **七牛云** | `qiniu/go-sdk/v7` |
| **本地文件系统** | 内置 |
| **Synology NAS** | 内置 |
| **CuCloud OSS** | 内置 |

### 2.8 其他关键依赖

| 技术 | 用途 |
|------|------|
| **MCP Go SDK** | `modelcontextprotocol/go-sdk` v1.4.0 — MCP 协议支持 |
| **Coraza WAF** | `corazawaf/coraza/v3` v3.3.3 — Web 应用防火墙 |
| **Prometheus** | `prometheus/client_golang` v1.19.0 — 监控指标 |
| **OpenTelemetry** | `opentelemetry.io/*` v1.40.0 — 分布式追踪 |
| **SCIM** | `elimity-com/scim` — SCIM 协议用户同步 |
| **SAML** | `russellhaering/gosaml2` — SAML 认证 |
| **LDAP** | `casdoor/ldapserver` + `go-ldap/ldap/v3` — LDAP 服务端/客户端 |
| **RADIUS** | `layeh.com/radius` — RADIUS 认证 |
| **Captcha** | `dchest/captcha` — 图形验证码 |
| **ACME/Let's Encrypt** | `casbin/lego/v4` — SSL 证书自动签发 |
| **Cron** | `robfig/cron/v3` — 定时任务 |
| **Excel** | `tealeg/xlsx` — Excel 导入导出 |
| **Whois** | `likexian/whois` — 域名 Whois 查询 |
| **系统监控** | `shirou/gopsutil/v4` — 系统信息采集 |

---

## 三、前端技术栈

### 3.1 核心框架

| 技术 | 版本 | 用途 |
|------|------|------|
| **React** | v18.2.0 | UI 框架 |
| **React Router** | v5.3.3 | 路由管理 |
| **Ant Design** | v5.24.1 | UI 组件库 |
| **Create React App** | v5.0.1 | 脚手架 |
| **CRACO** | v6.4.5 | CRA 配置覆盖 |

### 3.2 UI 与可视化

| 技术 | 用途 |
|------|------|
| **Ant Design Icons** | 图标库 |
| **@ant-design/cssinjs** | CSS-in-JS 方案 |
| **ECharts** | v5.4.3 — 数据可视化/图表 |
| **CodeMirror** | v6.0.1 — 代码编辑器（Casbin 策略编辑） |
| **react-cropper** | 图片裁剪 |
| **qrcode.react** | 二维码生成 |
| **face-api.js** | 人脸识别 |

### 3.3 工具库

| 技术 | 用途 |
|------|------|
| **i18next** + **react-i18next** | 国际化（11 种语言） |
| **moment** | 日期处理 |
| **crypto-js** | 前端加密 |
| **jwt-decode** | JWT 解码 |
| **copy-to-clipboard** | 剪贴板操作 |
| **file-saver** | 文件下载 |
| **xlsx** | Excel 处理 |
| **libphonenumber-js** | 电话号码验证 |
| **react-device-detect** | 设备检测 |
| **react-helmet** | HTML Head 管理 |
| **ethers** | v5.6.9 — Web3/区块链交互 |
| **@web3-onboard** | Web3 钱包连接 |

### 3.4 开发工具

| 技术 | 用途 |
|------|------|
| **ESLint** | v8.22.0 — JS 代码检查 |
| **Stylelint** | v14.11.0 — CSS/Less 检查 |
| **Husky** | v4.3.8 — Git hooks |
| **lint-staged** | v13.0.3 — 暂存区代码检查 |
| **Cypress** | v12.5.1 — E2E 测试 |
| **cross-env** | 跨平台环境变量 |
| **craco-less** | Less 支持 |

### 3.5 前端构建与代理

开发服务器通过 CRACO 配置代理，将 API 请求转发到后端：

```
/api           → http://127.0.0.1
/swagger       → http://127.0.0.1
/files         → http://127.0.0.1
/.well-known/* → http://127.0.0.1
/cas/**        → http://127.0.0.1
/scim          → http://127.0.0.1
```

---

## 四、代码结构详解

### 4.1 后端目录结构

```
casdoor/
├── main.go                  # 应用入口：初始化 Session、路由、过滤器、LDAP/RADIUS 服务
├── conf/                    # 配置管理
│   ├── app.conf             # 主配置文件（INI 格式）
│   ├── conf.go              # 配置读取（支持环境变量覆盖）
│   ├── conf_quota.go        # 配额配置
│   ├── conf_test.go         # 配置测试
│   ├── waf.conf             # WAF 规则配置（embed 嵌入）
│   └── web_config.go        # Web 配置
├── controllers/             # HTTP 控制器层（~60 个文件）
│   ├── base.go              # ApiController / RootController 基类
│   ├── account.go           # 账户管理
│   ├── auth.go              # 认证逻辑
│   ├── token.go             # Token 管理
│   ├── user.go              # 用户管理
│   ├── application.go       # 应用管理
│   ├── organization.go      # 组织管理
│   ├── mcp_server.go        # MCP 服务端点
│   ├── saml.go              # SAML 认证
│   ├── cas.go               # CAS 认证
│   ├── ldap.go              # LDAP 管理
│   ├── scim.go              # SCIM 协议
│   ├── webhook.go           # Webhook 管理
│   ├── mfa.go               # MFA 管理
│   ├── webauthn.go          # WebAuthn 管理
│   ├── payment.go           # 支付管理
│   ├── order.go             # 订单管理
│   └── ...                  # 其他资源 CRUD 控制器
├── object/                  # 业务逻辑与数据模型层（~120 个文件）
│   ├── ormer.go             # ORM 初始化（Xorm 引擎、数据库连接）
│   ├── init.go              # 内置数据初始化
│   ├── init_data.go         # JSON 数据导入
│   ├── init_data_dump.go    # 数据导出
│   ├── user.go              # User 模型与 CRUD
│   ├── organization.go      # Organization 模型
│   ├── application.go       # Application 模型
│   ├── token.go             # Token 模型
│   ├── token_jwt.go         # JWT 签发与验证
│   ├── token_oauth.go       # OAuth Token 处理
│   ├── permission.go        # Permission 模型
│   ├── permission_enforcer.go # 权限执行
│   ├── syncer_*.go          # 多种同步器实现
│   ├── webhook.go           # Webhook 模型与投递
│   ├── mfa_*.go             # MFA 实现（TOTP/SMS/Push/RADIUS）
│   ├── site_*.go            # 站点管理与证书
│   ├── rule.go              # 规则引擎
│   └── ...                  # 其他模型
├── routers/                 # 路由与过滤器
│   ├── router.go            # 路由注册（~400 行 API 路由定义）
│   ├── cors_filter.go       # CORS 跨域过滤器
│   ├── authz_filter.go      # Casbin 权限过滤器
│   ├── auto_signin_filter.go # 自动登录过滤器
│   ├── static_filter.go     # 静态文件过滤器
│   ├── prometheus_filter.go # Prometheus 指标过滤器
│   ├── timeout_filter.go    # 超时过滤器
│   ├── field_validation_filter.go # 字段验证过滤器
│   ├── theme_filter.go      # 主题过滤器
│   ├── record.go            # 请求记录
│   └── mcp_util.go          # MCP 工具
├── authz/                   # 授权逻辑
│   └── authz.go             # Casbin 策略初始化与权限检查
├── idp/                     # 身份提供商实现（~30 个文件）
│   ├── provider.go          # IdP 接口定义
│   ├── github.go            # GitHub OAuth
│   ├── google.go            # Google OAuth
│   ├── wechat.go            # 微信登录
│   ├── metamask.go          # MetaMask Web3
│   └── ...                  # 其他 IdP
├── cred/                    # 密码凭证处理
│   ├── manager.go           # 凭证管理器接口
│   ├── argon2id.go          # Argon2id 哈希
│   ├── bcrypt.go            # BCrypt 哈希
│   ├── pbkdf2_*.go          # PBKDF2 哈希
│   ├── md5-user-salt.go     # MD5+Salt（兼容旧系统）
│   └── plain.go             # 明文（测试用）
├── captcha/                 # 验证码
│   ├── provider.go          # 验证码接口
│   ├── default.go           # 内置图形验证码
│   ├── recaptcha.go         # Google reCAPTCHA
│   ├── hcaptcha.go          # hCaptcha
│   ├── turnstile.go         # Cloudflare Turnstile
│   ├── geetest.go           # 极验
│   └── aliyun.go            # 阿里云验证码
├── email/                   # 邮件发送
│   ├── provider.go          # 邮件接口
│   ├── smtp.go              # SMTP
│   ├── sendgrid.go          # SendGrid
│   ├── resend.go            # Resend
│   └── azure_acs.go         # Azure ACS
├── notification/            # 通知推送（~20 个文件）
│   ├── provider.go          # 通知接口
│   └── *.go                 # 各平台实现
├── storage/                 # 对象存储（~10 个文件）
│   ├── storage.go           # 存储接口
│   └── *.go                 # 各云存储实现
├── pp/                      # 支付提供商（~15 个文件）
│   ├── provider.go          # 支付接口
│   └── *.go                 # 各支付平台实现
├── idv/                     # 身份验证
│   ├── provider.go          # IDV 接口
│   ├── aliyun.go            # 阿里云实人认证
│   └── jumio.go             # Jumio
├── faceId/                  # 人脸识别
│   ├── provider.go          # FaceID 接口
│   └── aliyun.go            # 阿里云人脸识别
├── ldap/                    # LDAP 服务器
│   ├── server.go            # LDAP 服务端
│   └── util.go              # LDAP 工具
├── radius/                  # RADIUS 服务器
│   ├── server.go            # RADIUS 服务端
│   └── util.go              # RADIUS 工具
├── scim/                    # SCIM 服务器
│   ├── server.go            # SCIM 路由
│   ├── user_handler.go      # SCIM 用户处理
│   └── util.go              # SCIM 工具
├── mcp/                     # MCP 工具
│   └── util.go              # MCP 工具函数
├── mcpself/                 # MCP 自身服务
│   ├── base.go              # MCP JSON-RPC 2.0 结构
│   ├── auth.go              # MCP 认证
│   ├── application.go       # MCP 应用
│   └── permission.go        # MCP 权限
├── log/                     # 日志采集
│   ├── provider.go          # 日志接口
│   ├── system_log.go        # 系统日志
│   ├── selinux_log.go       # SELinux 日志
│   └── agent_openclaw.go    # Agent 日志
├── ip/                      # IP 解析
│   ├── ip.go                # IP 工具
│   └── ip17mon.go           # IP17mon 库
├── rule/                    # 规则引擎
│   ├── rule.go              # 规则接口
│   ├── rule_ip.go           # IP 规则
│   ├── rule_ip_rate.go      # IP 速率规则
│   ├── rule_ua.go           # UA 规则
│   ├── rule_waf.go          # WAF 规则
│   └── rule_compound.go     # 复合规则
├── proxy/                   # HTTP 代理
│   └── proxy.go             # 代理客户端
├── service/                 # 服务层
│   ├── oauth.go             # OAuth 服务
│   ├── proxy.go             # 代理服务
│   └── util.go              # 服务工具
├── sync/                    # 数据库同步
│   ├── sync.go              # 同步引擎
│   ├── database.go          # 数据库同步
│   └── database_canal.go    # Canal 同步
├── sync_v2/                 # 数据库同步 V2
│   ├── master.go            # 主节点
│   └── slave.go             # 从节点
├── xlsx/                    # Excel 导入导出
│   ├── xlsx.go              # Excel 处理
│   └── *_test.xlsx          # 测试数据
├── util/                    # 工具函数
│   ├── casbin.go            # Casbin 工具
│   ├── crypto.go            # 加密工具
│   ├── json.go              # JSON 工具
│   ├── network.go           # 网络工具
│   ├── string.go            # 字符串工具
│   ├── time.go              # 时间工具
│   ├── validation.go        # 验证工具
│   └── ...                  # 其他工具
├── certificate/             # 证书管理
│   ├── account.go           # ACME 账户
│   ├── conf.go              # 证书配置
│   ├── dns.go               # DNS 验证
│   └── ecc.go               # ECC 证书
├── form/                    # 表单处理
│   ├── auth.go              # 认证表单
│   └── verification.go      # 验证表单
├── deployment/              # 部署工具
│   └── deploy.go            # 部署逻辑
└── swagger/                 # Swagger API 文档
    ├── swagger.json         # OpenAPI 规范
    └── swagger.yml          # YAML 格式
```

### 4.2 前端目录结构

```
web/
├── public/                  # 静态资源
│   ├── index.html           # HTML 模板
│   ├── AuthCallbackHandler.js  # 认证回调处理
│   └── ProviderHintRedirect.js # IdP 重定向
├── src/
│   ├── index.js             # 应用入口
│   ├── App.js               # 根组件（路由、主题、布局）
│   ├── App.less             # 全局样式
│   ├── Setting.js           # 全局设置与工具函数
│   ├── Conf.js              # 前端配置（从后端 Cookie 同步）
│   ├── i18n.js              # 国际化初始化
│   ├── auth/                # 认证相关页面
│   │   ├── Auth.js          # 认证配置
│   │   ├── AuthBackend.js   # 认证 API 调用
│   │   ├── AuthCallback.js  # OAuth 回调
│   │   ├── LoginPage.js     # 登录页
│   │   ├── SignupPage.js    # 注册页
│   │   ├── ForgetPage.js    # 忘记密码页
│   │   ├── Provider.js      # IdP 提供商
│   │   ├── ProviderButton.js # IdP 登录按钮
│   │   ├── mfa/             # MFA 子页面
│   │   │   ├── MfaVerifyTotpForm.js   # TOTP 验证
│   │   │   ├── MfaVerifySmsForm.js    # SMS 验证
│   │   │   ├── MfaVerifyPushForm.js   # Push 验证
│   │   │   └── MfaVerifyRadiusForm.js # RADIUS 验证
│   │   └── *LoginButton.js  # 各 IdP 登录按钮
│   ├── backend/             # API 后端调用层（~40 个文件）
│   │   ├── FetchFilter.js   # Fetch 拦截器（Demo 模式过滤）
│   │   ├── UserBackend.js   # 用户 API
│   │   ├── ApplicationBackend.js # 应用 API
│   │   ├── OrganizationBackend.js # 组织 API
│   │   ├── TokenBackend.js  # Token API
│   │   └── ...              # 其他资源 API
│   ├── table/               # 表格组件（~30 个文件）
│   │   ├── AccountTable.js  # 账户表格
│   │   ├── ProviderTable.js # 提供商表格
│   │   ├── PolicyTable.js   # 策略表格
│   │   └── ...              # 其他表格
│   ├── common/              # 通用组件
│   │   ├── modal/           # 模态框组件
│   │   ├── select/          # 选择器组件
│   │   ├── theme/           # 主题编辑器
│   │   ├── product/         # 产品组件
│   │   ├── notifaction/     # 通知组件
│   │   ├── CaptchaWidget.js # 验证码组件
│   │   ├── PasswordChecker.js # 密码强度检查
│   │   ├── Editor.js        # 代码编辑器
│   │   └── ...              # 其他通用组件
│   ├── provider/            # Provider 字段组件
│   │   ├── OAuthProviderFields.js
│   │   ├── EmailProviderFields.js
│   │   ├── SmsProviderFields.js
│   │   ├── StorageProviderFields.js
│   │   └── ...              # 其他 Provider 字段
│   ├── locales/             # 国际化资源（11 种语言）
│   │   ├── en/data.json
│   │   ├── zh/data.json
│   │   └── ...
│   ├── basic/               # 基础页面
│   │   ├── Dashboard.js     # 仪表盘
│   │   ├── AppListPage.js   # 应用列表
│   │   └── ShortcutsPage.js # 快捷方式
│   ├── pricing/             # 定价页面
│   ├── account/             # 账户页面
│   ├── *EditPage.js         # 各资源编辑页（~40 个）
│   ├── *ListPage.js         # 各资源列表页（~40 个）
│   ├── ManagementPage.js    # 管理后台主页
│   ├── EntryPage.js         # 入口页面（登录/注册）
│   ├── BaseListPage.js      # 列表页基类
│   ├── TourConfig.js        # 引导配置
│   └── CasbinEditor.js      # Casbin 策略编辑器
├── cypress/                 # E2E 测试
│   ├── e2e/                 # 测试用例（~20 个）
│   └── support/             # 测试支持
├── craco.config.js          # CRACO 配置（代理、Less、Webpack）
├── package.json             # 依赖管理
├── .env                     # 环境变量
└── yarn.lock                # 依赖锁定
```

---

## 五、架构设计

### 5.1 整体架构

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│   浏览器     │────▶│  Traefik 网关     │────▶│  Casdoor    │
│  (React SPA) │◀────│  (可选反向代理)    │◀────│  后端服务    │
└─────────────┘     └──────────────────┘     └──────┬──────┘
                                                     │
                              ┌───────────────────────┼───────────────────────┐
                              │                       │                       │
                        ┌─────▼─────┐          ┌──────▼──────┐        ┌──────▼──────┐
                        │  数据库     │          │  Redis      │        │  外部服务    │
                        │ MySQL/PG/  │          │  (Session)  │        │ (IdP/邮件/  │
                        │ SQLite     │          │             │        │  短信/存储)  │
                        └───────────┘          └─────────────┘        └─────────────┘
```

### 5.2 请求处理流程

```
HTTP 请求
  │
  ▼
Beego 过滤器链（BeforeRouter）:
  1. StaticFilter      → 静态文件处理
  2. AutoSigninFilter  → 自动登录检测
  3. CorsFilter        → CORS 跨域处理
  4. TimeoutFilter     → 请求超时控制
  5. ApiFilter         → Casbin 权限校验
  6. PrometheusFilter  → 指标采集
  7. RecordMessage     → 请求记录
  8. FieldValidationFilter → 字段验证
  │
  ▼
Controller 处理:
  ApiController  → /api/* 路由
  RootController → / 根路由（OIDC Discovery、CAS、SCIM、JWKS）
  │
  ▼
Object 业务逻辑层:
  数据验证 → 业务处理 → ORM 操作 → 数据库
  │
  ▼
AfterExec 过滤器:
  AfterRecordMessage → 响应记录
```

### 5.3 控制器分层

```
Controller 层 (controllers/)
  ├── 参数解析与验证
  ├── 权限检查（IsAdmin / IsGlobalAdmin / IsAdminOrSelf）
  ├── 调用 Object 层业务逻辑
  └── 返回 JSON 响应

Object 层 (object/)
  ├── 数据模型定义（struct）
  ├── 业务逻辑实现
  ├── 数据库 CRUD 操作（通过 Xorm）
  └── 跨模型协调逻辑

Provider 层 (idp/ email/ storage/ pp/ notification/ ...)
  ├── 外部服务接口定义
  └── 各提供商具体实现
```

### 5.4 前后端通信

- **开发模式**: CRACO devServer 代理 `/api` → `http://127.0.0.1`
- **生产模式**: Go 后端直接托管前端静态文件（`web/build`）
- **API 格式**: RESTful JSON
- **认证方式**: Cookie Session + Access Token（Bearer）
- **CORS**: 后端 CorsFilter 根据配置的 `origin` 和 `originFrontend` 控制跨域

---

## 六、数据库模型

Casdoor 使用 Xorm 自动建表（`Sync2`），主要数据模型包括：

| 模型 | 说明 |
|------|------|
| Organization | 组织 |
| Group | 用户组 |
| User | 用户 |
| Invitation | 邀请码 |
| Application | 应用 |
| Provider | 提供商配置 |
| Resource | 资源文件 |
| Cert | SSL 证书 |
| Key | 密钥 |
| Role | 角色 |
| Permission | 权限 |
| Model | Casbin 模型 |
| Adapter | Casbin 适配器 |
| Enforcer | Casbin 执行器 |
| Session | 会话 |
| Token | 令牌 |
| Product | 产品 |
| Payment | 支付 |
| Order | 订单 |
| Plan | 计划 |
| Pricing | 定价 |
| Subscription | 订阅 |
| Transaction | 交易 |
| Syncer | 同步器 |
| Record | 操作记录 |
| Webhook | Webhook 配置 |
| WebhookEvent | Webhook 事件 |
| VerificationRecord | 验证记录 |
| Ldap | LDAP 配置 |
| RadiusAccounting | RADIUS 记账 |
| CasbinRule | Casbin 策略规则 |
| Form | 表单 |
| Ticket | 工单 |
| Agent | AI 代理 |
| Server | MCP 服务器 |
| Entry | 日志条目 |
| Site | 站点 |
| Rule | 规则 |

---

## 七、配置体系

### 7.1 后端配置（conf/app.conf）

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `appname` | casdoor | 应用名称 |
| `httpport` | 8080 | HTTP 端口 |
| `runmode` | dev | 运行模式 |
| `driverName` | sqlite | 数据库驱动 |
| `dataSourceName` | file:casdoor.db | 数据源 |
| `dbName` | | 数据库名 |
| `redisEndpoint` | | Redis 连接（Session 存储） |
| `origin` | http://localhost | 后端 Origin（CORS） |
| `originFrontend` | http://localhost | 前端 Origin |
| `staticBaseUrl` | https://cdn.casbin.org | 静态资源 CDN |
| `isDemoMode` | false | 演示模式 |
| `verificationCodeTimeout` | 10 | 验证码超时（分钟） |
| `ldapServerPort` | 389 | LDAP 端口 |
| `radiusServerPort` | 1812 | RADIUS 端口 |
| `logConfig` | JSON | 日志配置 |
| `frontendBaseDir` | ./web/build | 前端构建目录 |

**环境变量覆盖**: 所有配置项均可通过同名环境变量覆盖（`conf.GetConfigString` 优先读取 `os.LookupEnv`）。

### 7.2 前端配置

- **编译时**: `web/src/Conf.js` 定义默认值
- **运行时**: 通过 Cookie `jsonWebConfig` 从后端同步配置
- **环境变量**: `REACT_APP_API_URL` / `REACT_APP_FRONTEND_URL`

---

## 八、部署方案

### 8.1 Docker 多阶段构建

```dockerfile
# 阶段1: 前端构建 (Node 20.20.1)
# 阶段2: 后端构建 (Go 1.25.8)
# 阶段3a: 标准镜像 (Alpine) — 仅 Casdoor 服务
# 阶段3b: All-in-One 镜像 (Debian) — 包含数据库等
```

### 8.2 Docker Compose

```yaml
services:
  casdoor:    # Casdoor 应用 (端口 8000)
  mysql:      # MySQL 8.0 (端口 3306)
  traefik:    # Traefik 网关 (端口 80/443/8080)
```

### 8.3 Kubernetes

- 使用 Helm Chart 部署（`manifests/casdoor`）
- 支持 Ingress 配置
- 命令: `helm upgrade --install`

---

## 九、测试体系

| 类型 | 工具 | 位置 |
|------|------|------|
| **Go 单元测试** | `go test` | `*_test.go`（各包内） |
| **前端 E2E 测试** | Cypress v12.5.1 | `web/cypress/e2e/` |
| **覆盖率** | `go tool cover` | `make ut` |
| **代码检查** | golangci-lint v2.11.4 | `make lint` |
| **前端 Lint** | ESLint + Stylelint | `npm run fix` / `npm run lint:css` |

---

## 十、API 路由概览

### 核心 API

| 路径 | 方法 | 说明 |
|------|------|------|
| `/api/login` | POST | 登录 |
| `/api/signup` | POST | 注册 |
| `/api/logout` | GET/POST | 登出 |
| `/api/get-account` | GET | 获取当前账户 |
| `/api/userinfo` | GET | OIDC UserInfo 端点 |
| `/api/health` | GET | 健康检查 |

### OAuth/OIDC

| 路径 | 方法 | 说明 |
|------|------|------|
| `/api/login/oauth/access_token` | POST | 获取 Token |
| `/api/login/oauth/refresh_token` | POST | 刷新 Token |
| `/api/login/oauth/introspect` | POST | Token 内省 |
| `/api/oauth/register` | POST | DCR 动态注册 |
| `/.well-known/openid-configuration` | GET | OIDC Discovery |
| `/.well-known/jwks` | GET | JWKS 端点 |

### MCP

| 路径 | 方法 | 说明 |
|------|------|------|
| `/api/mcp` | POST | MCP JSON-RPC 端点 |

### CAS

| 路径 | 方法 | 说明 |
|------|------|------|
| `/cas/:org/:app/serviceValidate` | GET | CAS Service 验证 |
| `/cas/:org/:app/proxyValidate` | GET | CAS Proxy 验证 |
| `/cas/:org/:app/samlValidate` | POST | CAS SAML 验证 |

### SCIM

| 路径 | 方法 | 说明 |
|------|------|------|
| `/scim/*` | * | SCIM 协议端点 |

---

## 十一、扩展点设计

Casdoor 采用 **Provider 接口模式** 实现可插拔架构，主要扩展点：

| 扩展点 | 接口文件 | 已实现数量 |
|--------|----------|-----------|
| 身份提供商 (IdP) | `idp/provider.go` | ~30 |
| 邮件服务 | `email/provider.go` | 5 |
| 短信服务 | `object/sms.go` | ~8 |
| 通知服务 | `notification/provider.go` | ~20 |
| 对象存储 | `storage/storage.go` | ~10 |
| 支付服务 | `pp/provider.go` | ~12 |
| 验证码 | `captcha/provider.go` | 6 |
| 人脸识别 | `faceId/provider.go` | 1 |
| 身份验证 | `idv/provider.go` | 2 |
| 日志服务 | `log/provider.go` | 4 |
| 密码哈希 | `cred/manager.go` | 7 |
| 数据同步 | `object/syncer_interface.go` | ~10 |

每个 Provider 均通过统一接口定义，新增提供商只需实现接口并注册即可。
