# Merge Upstream 技能

将 upstream（原始开源项目）的更新合并到 origin（分支项目）的 Trae IDE 技能。

## 功能概述

- **可配置工作目录** — 指定任意目录作为操作目标
- **可配置仓库地址** — 指定 upstream 和 fork 的 Git 仓库 URL
- **自动 Clone** — 工作目录不存在时自动 clone 分支项目
- **智能 Remote 识别** — 通过 URL 匹配识别 remote，适配任意命名约定
- **Verbose 日志** — 详细的步骤级日志输出，默认开启
- 拉取最新代码并分析差异
- 智能检测潜在冲突
- 提供三种合并策略：直接合并 / Rebase / Squash
- 交互式冲突解决引导
- 合并后自动验证（构建 + 测试）
- 项目专属冲突优先级规则

## 安装

### 方式一：手动安装

将 `SKILL.md` 文件放置到 Trae 技能目录中：

```
<项目根目录>/.trae/skills/merge-upstream/SKILL.md
```

目录结构如下：

```
your-project/
└── .trae/
    └── skills/
        └── merge-upstream/
            ├── SKILL.md
            └── README.md
```

### 方式二：命令行安装

在项目根目录下执行：

```bash
mkdir -p .trae/skills/merge-upstream
```

然后将 `SKILL.md` 和 `README.md` 文件复制到 `.trae/skills/merge-upstream/` 目录中。

## 配置

技能通过三级优先级读取配置：

1. **用户输入参数**（最高优先级）— 在对话中直接指定
2. **环境变量** — 在 `.env` 或系统环境中设置
3. **默认值**（最低优先级）— 内置默认值

### 参数列表

| 参数                | 环境变量                    | 默认值                                         | 说明                                     |
| ----------------- | ----------------------- | ------------------------------------------- | -------------------------------------- |
| `WORK_DIR`        | `MERGE_WORK_DIR`        | 当前目录                                        | 工作目录路径                                 |
| `UPSTREAM_REPO`   | `MERGE_UPSTREAM_REPO`   | `https://github.com/casdoor/casdoor.git`    | 原始开源项目仓库 URL                           |
| `FORK_REPO`       | `MERGE_FORK_REPO`       | `https://github.com/xiaoruiguo/casdoor.git` | 分支项目仓库 URL                             |
| `FORK_BRANCH`     | `MERGE_FORK_BRANCH`     | `master`                                    | 分支项目目标分支                               |
| `UPSTREAM_BRANCH` | `MERGE_UPSTREAM_BRANCH` | `master`                                    | 上游项目源分支                                |
| `MERGE_STRATEGY`  | `MERGE_STRATEGY`        | `merge`                                     | 合并策略：`merge` / `rebase` / `squash`     |
| `GITHUB_TOKEN`    | `MERGE_GITHUB_TOKEN`    | *(空)*                                       | GitHub 个人访问令牌（PAT），用于认证                |
| `GIT_AUTH_METHOD` | `MERGE_GIT_AUTH_METHOD` | `auto`                                      | 认证方式：`auto` / `token` / `ssh` / `none` |
| `RETRY_COUNT`     | `MERGE_RETRY_COUNT`     | `10`                                        | Clone/Fetch 最大重试次数                     |
| `VERBOSE`         | `MERGE_VERBOSE`         | `true`                                      | 详细日志输出：`true` / `false`                |

### 使用示例

#### 基础用法

```
"同步上游更新"                              # 使用全部默认配置
"合并 upstream 到 origin"                   # 同上
"sync with upstream"                        # 同上（英文）
```

#### 指定工作目录

```
"在 D:\projects\my-casdoor 同步上游更新"
"merge upstream into /home/user/casdoor"
"把 C:\code\fork-repo 的上游更新合并一下"
```

#### 指定仓库地址

```
"sync https://github.com/myorg/casdoor from https://github.com/casdoor/casdoor"
"上游是 https://github.com/casdoor/casdoor.git，分支是 https://github.com/myorg/casdoor.git，合并上游更新"
```

#### 指定分支

```
"把 upstream 的 develop 分支合并到我的 feature 分支"
"合并上游 main 分支的更新到当前分支"
```

#### 指定合并策略

```
"用 rebase 方式同步上游更新"
"squash merge upstream changes"
"用 squash 合并上游更新到我的仓库"
```

#### 指定认证方式

```
"用 token 认证同步上游更新"                    # GIT_AUTH_METHOD=token
"用 SSH 方式合并上游更新"                      # GIT_AUTH_METHOD=ssh
"无需认证同步上游更新"                         # GIT_AUTH_METHOD=none（公开仓库）
"用 ghp_xxxx 认证同步上游"                     # 直接提供 token 值
```

#### 控制日志输出

```
"安静模式同步上游更新"                       # VERBOSE=false
"quiet mode sync upstream"                  # VERBOSE=false
"详细日志同步上游更新"                       # VERBOSE=true（默认）
```

#### 组合指定

```
"在 D:\projects\casdoor 用 rebase 合并 https://github.com/casdoor/casdoor 的 master 分支更新"
"工作目录 /home/user/repo，上游 https://github.com/upstream/project.git，分支 https://github.com/myorg/project.git，squash 合并"
```

#### 从零开始（工作目录不存在）

```
"克隆 https://github.com/myorg/casdoor 到 D:\new-project 并合并上游 https://github.com/casdoor/casdoor 的更新"
"在 C:\workspace\my-fork 同步上游更新，我的仓库是 https://github.com/me/casdoor.git"
```

> **提示**：技能会从用户输入中自动提取参数。未指定的参数会依次从环境变量和默认值中读取。

## GitHub 认证

访问 GitHub 仓库时可能需要认证，尤其是私有仓库或推送操作。

### 认证方式

| 方式           | `GIT_AUTH_METHOD` | 说明                                     | 适用场景            |
| ------------ | ----------------- | -------------------------------------- | --------------- |
| **自动检测**     | `auto`（默认）        | 依次尝试 SSH → Token → 无认证                 | 大多数情况           |
| **Token 认证** | `token`           | 使用 GitHub PAT 嵌入 HTTPS URL             | 无 SSH 配置的环境     |
| **SSH 认证**   | `ssh`             | 使用 SSH 密钥，URL 转换为 `git@github.com:` 格式 | 已配置 SSH Key 的环境 |
| **无认证**      | `none`            | 不使用任何认证                                | 仅公开仓库的读取操作      |

### Token 认证配置

1. 在 GitHub 生成 Personal Access Token（Settings → Developer settings → Personal access tokens）
2. 所需权限：`repo`（完整仓库访问）、`read:org`（读取组织）
3. 设置方式（任选其一）：

```bash
# 方式一：环境变量
export MERGE_GITHUB_TOKEN=ghp_xxxxxxxxxxxx

# 方式二：.env 文件
echo "MERGE_GITHUB_TOKEN=ghp_xxxxxxxxxxxx" >> .env

# 方式三：对话中直接指定
"用 ghp_xxxxxxxxxxxx 认证同步上游更新"
```

### SSH 认证配置

1. 生成 SSH 密钥：`ssh-keygen -t ed25519 -C "your@email.com"`
2. 添加到 GitHub：Settings → SSH and GPG keys → New SSH key
3. 测试连接：`ssh -T git@github.com`
4. 设置方式：

```bash
# 环境变量
export MERGE_GIT_AUTH_METHOD=ssh

# 或对话中指定
"用 SSH 方式合并上游更新"
```

### 安全注意事项

- ⚠️ **Token 不会被记录到日志中**，Verbose 输出仅显示 `<set>` 或 `<unset>`
- ⚠️ **不要将 Token 提交到 Git 仓库**，使用 `.env` 文件时应将其加入 `.gitignore`
- ⚠️ Token 嵌入 URL 后，`git remote -v` 会显示 Token 值，合并完成后建议重置 URL

## Verbose 日志

### 日志格式

每条日志遵循统一格式：

```
[merge-upstream] [STEP-N] [LEVEL] message
```

| 字段       | 说明                        |
| -------- | ------------------------- |
| `STEP-N` | 步骤编号（如 `STEP-0`、`STEP-1`） |
| `LEVEL`  | 日志级别                      |

### 日志级别

| 级别       | 含义      | 颜色标识  |
| -------- | ------- | ----- |
| `INFO`   | 一般进度信息  | 白色    |
| `WARN`   | 需要注意的警告 | 黄色 ⚠️ |
| `ERROR`  | 阻塞进度的错误 | 红色 ❌  |
| `CMD`    | 正在执行的命令 | 蓝色    |
| `RESULT` | 命令执行结果  | 绿色    |

### Verbose vs Quiet 模式对比

| 方面        | `VERBOSE=true`（默认）     | `VERBOSE=false` |
| --------- | ---------------------- | --------------- |
| 步骤标题      | ✅ 显示步骤编号、标题、描述         | ✅ 仅显示步骤编号和标题    |
| 执行命令      | ✅ 显示完整命令               | ❌ 隐藏            |
| 命令输出      | ✅ 显示完整输出               | ❌ 仅显示摘要         |
| Remote 检测 | ✅ 显示 URL 匹配详情          | ❌ 仅显示结果         |
| 差异分析      | ✅ 显示文件级详情              | ❌ 仅显示数量         |
| 冲突详情      | ✅ 显示冲突标记               | ✅ 始终显示（关键信息）    |
| 耗时统计      | ✅ 显示每步耗时               | ❌ 不显示           |
| 配置来源      | ✅ 显示参数值及来源             | ✅ 仅显示参数值        |
| Token 值   | ❌ 永远不显示（仅显示 set/unset） | ❌ 永远不显示         |
| 最终汇总      | ✅ 始终显示                 | ✅ 始终显示          |

### 日志输出示例

```
[merge-upstream] [STEP-0] [INFO] ===== Resolving Configuration =====
[merge-upstream] [STEP-0] [INFO] Parameter: WORK_DIR = D:\claude\casdoor (source: default)
[merge-upstream] [STEP-0] [INFO] Parameter: UPSTREAM_REPO = https://github.com/casdoor/casdoor.git (source: default)
[merge-upstream] [STEP-0] [INFO] Parameter: GITHUB_TOKEN = set (source: env)
[merge-upstream] [STEP-0] [INFO] Parameter: GIT_AUTH_METHOD = token (source: env)
[merge-upstream] [STEP-0] [INFO] Parameter: VERBOSE = true (source: default)
[merge-upstream] [STEP-0] [RESULT] Configuration resolved successfully

[merge-upstream] [STEP-1] [INFO] ===== Environment Setup =====
[merge-upstream] [STEP-1] [INFO] Checking WORK_DIR: D:\claude\casdoor
[merge-upstream] [STEP-1] [INFO] Directory exists: true
[merge-upstream] [STEP-1] [INFO] Is git repo: true
[merge-upstream] [STEP-1] [INFO] Auth method: token
[merge-upstream] [STEP-1] [INFO] GITHUB_TOKEN: set
[merge-upstream] [STEP-1] [INFO] SSH key: not found
[merge-upstream] [STEP-1] [CMD] git remote -v
[merge-upstream] [STEP-1] [RESULT] origin  https://github.com/casdoor/casdoor.git (fetch)
[merge-upstream] [STEP-1] [RESULT] upstream  https://github.com/xiaoruiguo/casdoor.git (fetch)
[merge-upstream] [STEP-1] [INFO] Remote URL matching:
[merge-upstream] [STEP-1] [INFO]   remote 'origin' URL 'https://github.com/casdoor/casdoor.git' → matches UPSTREAM_REPO: true
[merge-upstream] [STEP-1] [INFO]   remote 'upstream' URL 'https://github.com/xiaoruiguo/casdoor.git' → matches FORK_REPO: true
[merge-upstream] [STEP-1] [INFO] Resolved: UPSTREAM_REMOTE = origin, FORK_REMOTE = upstream
[merge-upstream] [STEP-1] [INFO] Applying authentication to remotes...
[merge-upstream] [STEP-1] [INFO]   origin: URL rewritten for token auth
[merge-upstream] [STEP-1] [INFO]   upstream: URL rewritten for token auth
[merge-upstream] [STEP-1] [RESULT] Environment ready: opened existing

[merge-upstream] [STEP-4] [INFO] ===== Analyzing Differences =====
[merge-upstream] [STEP-4] [CMD] git log --oneline upstream/master..origin/master
[merge-upstream] [STEP-4] [RESULT] no new commits
[merge-upstream] [STEP-4] [INFO] New commits from upstream: 0
[merge-upstream] [STEP-4] [RESULT] Analysis complete: 0 new commits, 0 files changed

[merge-upstream] [DONE] ===== Merge Complete =====
[merge-upstream] [DONE] Work Dir:       D:\claude\casdoor
[merge-upstream] [DONE] Upstream:       https://github.com/casdoor/casdoor.git (master)
[merge-upstream] [DONE] Fork:           https://github.com/xiaoruiguo/casdoor.git (master)
[merge-upstream] [DONE] Strategy:       merge
[merge-upstream] [DONE] Auth Method:    token
[merge-upstream] [DONE] New Commits:    0
[merge-upstream] [DONE] Conflicts:      0
[merge-upstream] [DONE] Build:          SKIPPED
[merge-upstream] [DONE] Tests:          SKIPPED
[merge-upstream] [DONE] Pushed:         NO
[merge-upstream] [DONE] Stash Restored: YES
[merge-upstream] [DONE] Total Time:     0m 12s
```

## 使用方法

### 触发方式

在 Trae IDE 对话中，使用以下任意表述即可触发技能：

- "合并 upstream 到 origin"
- "同步上游更新"
- "拉取 upstream 最新代码"
- "merge upstream changes"
- "sync with upstream"

### 执行流程

```
┌──────────────┐
│  0. 解析配置  │  读取参数、环境变量、默认值
└──────┬───────┘
       ▼
┌──────────────┐
│  1. 环境准备  │  检查工作目录 → Clone 或打开现有仓库
└──────┬───────┘
       ▼
┌──────────────┐
│  2. 预检查    │  检查工作区状态、未提交变更
└──────┬───────┘
       ▼
┌──────────────┐
│  3. 拉取代码  │  git fetch --all
└──────┬───────┘
       ▼
┌──────────────┐
│  4. 分析差异  │  展示待合并的提交和文件变更
└──────┬───────┘
       ▼
┌──────────────┐
│  5. 冲突检测  │  识别双方都修改的文件
└──────┬───────┘
       ▼
┌──────────────┐
│  6. 执行合并  │  选择合并策略并执行
└──────┬───────┘
       ▼
┌──────────────┐
│  7. 解决冲突  │  逐文件交互式解决（如有）
└──────┬───────┘
       ▼
┌──────────────┐
│  8. 验证合并  │  构建 + 测试
└──────┬───────┘
       ▼
┌──────────────┐
│  9. 推送变更  │  确认后推送到分支项目
└──────┬───────┘
       ▼
┌──────────────┐
│ 10. 恢复暂存  │  恢复之前 stash 的变更
└──────┬───────┘
       ▼
┌──────────────┐
│  汇总报告    │  输出最终合并结果摘要
└──────────────┘
```

### 环境准备详解

技能会根据工作目录状态自动选择操作：

| 工作目录状态                  | 操作                                                    |
| ----------------------- | ----------------------------------------------------- |
| 目录不存在                   | `git clone $FORK_REPO $WORK_DIR` → 添加 upstream remote |
| 目录存在但非 Git 仓库           | `git clone $FORK_REPO $WORK_DIR` → 添加 upstream remote |
| 已有 Git 仓库且匹配 FORK\_REPO | 验证 remotes → 缺少 upstream 则添加                          |
| 已有 Git 仓库但不匹配           | 报错，提示用户确认                                             |

### 合并策略

| 策略           | 命令                                                     | 适用场景           |
| ------------ | ------------------------------------------------------ | -------------- |
| **直接合并**（默认） | `git merge $UPSTREAM_REMOTE/$UPSTREAM_BRANCH`          | 保留完整历史，推荐大多数情况 |
| **Rebase**   | `git rebase $UPSTREAM_REMOTE/$UPSTREAM_BRANCH`         | 需要线性历史         |
| **Squash**   | `git merge --squash $UPSTREAM_REMOTE/$UPSTREAM_BRANCH` | 压缩所有上游变更为一个提交  |

### Remote 识别机制

技能**通过 URL 匹配**识别 remote，而非依赖 remote 名称：

1. 遍历所有 remote，检查其 URL
2. URL 匹配 `UPSTREAM_REPO` 的 remote → `UPSTREAM_REMOTE`
3. URL 匹配 `FORK_REPO` 的 remote → `FORK_REMOTE`
4. 无匹配则自动添加

这确保了即使 remote 命名与常规约定不同（如本项目中 `origin` 指向原始项目、`upstream` 指向分支项目），也能正确识别。

### 冲突解决优先级

| 文件类型                                            | 优先策略   | 说明             |
| ----------------------------------------------- | ------ | -------------- |
| 配置文件 (`app.conf`, `.env`, `docker-compose.yml`) | 保留分支版本 | 保留本地自定义配置      |
| 业务代码 (`controllers/`, `object/`)                | 采用上游版本 | 获取最新 bug 修复和功能 |
| 前端代码 (`web/src/`)                               | 采用上游版本 | 再重新应用自定义主题     |
| 依赖文件 (`go.mod`, `package.json`)                 | 采用上游版本 | 获取安全补丁         |
| 文档 (`*.md`)                                     | 合并双方   | 保留分支特有内容       |

## 错误恢复

| 操作     | 命令                          |
| ------ | --------------------------- |
| 中止合并   | `git merge --abort`         |
| 中止变基   | `git rebase --abort`        |
| 重置到合并前 | `git reset --hard <合并前的提交>` |
| 暂存当前修改 | `git stash`                 |
| 恢复暂存   | `git stash pop`             |

错误恢复时 Verbose 输出：

```
[merge-upstream] [ERROR] Merge failed: <error message>
[merge-upstream] [ERROR] Initiating recovery...
[merge-upstream] [ERROR] [CMD] git merge --abort
[merge-upstream] [ERROR] [RESULT] Merge aborted, working tree restored
[merge-upstream] [ERROR] Recovery complete. You can retry or investigate manually.
```

## 文件结构

```
.trae/skills/merge-upstream/
├── SKILL.md      # 技能定义文件
└── README.md     # 本说明文件
```

## 前置条件

- Git >= 2.0
- 网络可访问目标 Git 仓库（或本地已有缓存）
- 对 fork 仓库有写入权限（推送时需要）
- 对 upstream 仓库有读取权限
- 认证要求（满足其一即可）：
  - GitHub Personal Access Token（`GITHUB_TOKEN`），推荐 Fine-grained token
  - SSH 密钥已配置（`~/.ssh/id_*` + GitHub SSH Key）
  - 仓库为公开仓库且仅需读取（`GIT_AUTH_METHOD=none`）

使用如下参数，测试.

MERGE_WORK_DIR=D:\test2\casdoor
#/opt/data/workspace/
MERGE_UPSTREAM_REPO=https://github.com/casdoor/casdoor.git
MERGE_FORK_REPO=https://github.com/xiaoruiguo/casdoor.git
MERGE_FORK_BRANCH=master
MERGE_UPSTREAM_BRANCH=master
MERGE_STRATEGY=merge
MERGE_VERBOSE=true
GITHUB_TOKEN=**
MERGE_RETRY_C