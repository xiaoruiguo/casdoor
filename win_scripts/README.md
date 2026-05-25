# Windows Agent 升级脚本

PowerShell 5.1 版本的 Windows Agent 在线升级脚本，用于自动化升级 kernel 和 shadow 组件。

## 环境要求

- Windows Server 2016 / Windows 10 及以上
- PowerShell 5.1（系统自带）
- 管理员权限
- 网络可访问下载服务器（从 `kernel.toml` 中 `http_address` 获取）

## 目录结构

```
<Agent安装目录>/
├── kernel.exe
├── kernel.toml
├── state.toml
├── plugins/
│   └── shadow/
│       ├── shadow.exe
│       └── config.yaml
└── win_scripts/
    ├── update_optimized.ps1   ← 本脚本
    └── upgrade/
        ├── backup/            ← 备份文件
        │   └── plugins/shadow/
        ├── download/          ← 下载缓存
        └── logs/              ← 会话日志
```

脚本通过相对路径 `..\..\..\..` 回溯定位到 Agent 安装目录（`WORK_DIR`）。

## 参数说明

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `--version` | string | 是 | - | 目标升级版本号，格式如 `v1.4.5` |
| `--retry-count` | int | 否 | 3 | 下载失败重试次数 |
| `--skip-cert-check` | flag | 否 | 启用 | 跳过 HTTPS 证书校验（默认跳过） |
| `--no-skip-cert-check` | flag | 否 | - | 启用 HTTPS 证书校验 |
| `--log-transcript` | flag | 否 | 启用 | 启用会话日志记录 |
| `--no-log-transcript` | flag | 否 | - | 禁用会话日志记录 |
| `--help` | flag | 否 | - | 显示帮助信息 |

## 使用方法

### 基本用法

```powershell
.\update_optimized.ps1 --version v1.4.5
```

### 增加重试次数

网络不稳定时，增加下载重试次数：

```powershell
.\update_optimized.ps1 --version v1.4.5 --retry-count 10
```

### 禁用日志记录

默认会在 `upgrade/logs/` 下生成带时间戳的完整会话日志。如不需要：

```powershell
.\update_optimized.ps1 --version v1.4.5 --no-log-transcript
```

### 查看帮助

```powershell
.\update_optimized.ps1 --help
```

## 执行流程

```
1. 初始化环境        → 解析脚本路径、工作目录、升级目录
2. 校验升级版本      → 版本号必须 >= REQUIRED_VERSION (v1.4.4)
3. 清理历史缓存      → 清除 plugins 下的 .tar/.checksum 和 backup 文件
4. 解析下载服务器    → 从 kernel.toml 读取 http_address
5. 初始化升级目录    → 创建 backup/download 子目录
6. 检测系统架构      → 固定 amd64
7. 备份当前文件      → 备份 kernel.exe / kernel.toml / state.toml / shadow.exe
8. tar 工具检测      → 优先使用系统自带 tar，否则下载安装 GnuWin32 tar
9. 下载升级包        → 带重试的 HTTPS 下载，校验文件大小
10. 解压升级包       → 使用 tar 解压到临时目录
11. 禁止服务自动恢复 → sc.exe 关闭 kernel 服务的自动恢复和自动启动
12. 停止 shadow.exe  → 带超时的进程停止（默认30s）
13. 停止 kernel.exe  → 带超时的进程停止（默认30s）
14. 替换 kernel.exe  → 从升级包复制，失败则回滚
15. 替换 shadow.exe  → 从升级包复制，生成 config.yaml（无BOM），失败则回滚
16. 恢复服务配置     → 恢复自动启动和失败自动恢复策略
17. 启动 kernel 服务 → 启动失败则自动回滚并尝试恢复旧版本
18. 查看服务状态     → 输出 kernel 服务状态和启动类型
19. 验证版本输出     → 执行 kernel.exe -version 和 shadow.exe --version
20. 清理临时文件     → 删除解压临时目录
```

## 安全特性

| 特性 | 说明 |
|------|------|
| TLS 1.2 | 全局启用 `Tls12` 协议 |
| 证书绕过 | 支持 HTTPS 自签名证书环境 |
| 下载校验 | 验证文件存在且大小非零 |
| 下载重试 | 默认3次重试，间隔5秒 |
| 进程超时 | 停止进程默认30s超时，防止无限挂起 |
| 自动回滚 | 文件替换或服务启动失败时自动恢复备份 |
| 全局异常捕获 | `trap` + `try/finally` 确保资源清理 |
| 无 BOM 写入 | config.yaml 使用 `UTF8Encoding($false)` 避免写入 BOM |

## 回滚机制

脚本在以下失败场景会自动触发回滚（`Restore-Backup`）：

- 升级包中缺少 `kernel.exe`
- 升级包中缺少 `shadow.exe`
- `kernel` 服务启动失败

回滚操作会从 `upgrade/backup/` 恢复以下文件：

- `kernel.exe`
- `kernel.toml`
- `state.toml`
- `plugins\shadow\shadow.exe`

## 日志

启用日志时（默认），每次升级的完整控制台输出会保存到：

```
upgrade/logs/update_20260525_143000.log
```

日志文件名包含时间戳，不会覆盖历史记录。

## 退出码

| 退出码 | 含义 |
|--------|------|
| 0 | 升级成功 |
| 1 | 升级失败（版本校验失败、下载失败、解压失败、服务启动失败等） |

## 与 update.bat 的差异

| 对比项 | update.bat | update_optimized.ps1 |
|--------|-----------|---------------------|
| TLS/证书配置 | 内联 PowerShell 设置 | 脚本开头全局设置 |
| 进程停止 | 无限循环等待 | 30s 超时保护 |
| config.yaml 编码 | ANSI | UTF-8 无 BOM |
| 回滚机制 | 无 | 自动回滚 |
| 下载重试 | 无 | 默认3次 |
| 日志记录 | 无 | Start-Transcript |
| tar 工具 | 每次下载 GnuWin32 | 优先使用系统自带 |
| 异常保护 | 无 | trap + try/finally |
