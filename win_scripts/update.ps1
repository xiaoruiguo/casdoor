<#
.SYNOPSIS
    Windows Agent 升级脚本 (PowerShell 版本)

.DESCRIPTION
    功能：
        1. 校验升级版本号
        2. 自动解析下载服务器地址
        3. 下载并安装 tar 解压工具
        4. 下载 agent 升级包
        5. 解压升级包
        6. 停止 kernel/shadow 进程
        7. 替换 kernel.exe 与 shadow.exe
        8. 恢复 Windows 服务配置
        9. 启动 kernel 服务

    特点：
        - 静默执行
        - 不依赖系统自带 tar
        - 不修改 PATH 环境变量
        - 自动关闭服务恢复策略
        - 支持 Windows Server 2016

    注意：
        - 脚本文件编码保存为 UTF-8 with BOM 或 UTF-8（PowerShell 5.1 默认支持 UTF-8）
        - 必须使用管理员权限运行

.PARAMETER Version
    目标升级版本号，格式如 v1.4.5

.EXAMPLE
    .\upgrade.ps1 -Version v1.4.5
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Version,

    [Parameter()]
    [switch]$Help
)

# 显示帮助
if ($Help) {
    Write-Host @"
用法：
    $($MyInvocation.MyCommand.Name) -Version [agent版本号]

示例：
    $($MyInvocation.MyCommand.Name) -Version v1.4.5
"@
    exit 0
}

# 要求管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[ERROR] 请以管理员身份运行此脚本！" -ForegroundColor Red
    exit 1
}

# 禁用进度条以提升下载速度（影响 Invoke-WebRequest 性能）
$ProgressPreference = 'SilentlyContinue'

# =======================================
# 1. 基础变量定义
# =======================================
$REQUIRED_VERSION = "v1.4.4"

# =======================================
# 2. 初始化环境
# =======================================
Write-Host "`n======================================="
Write-Host "初始化运行环境"
Write-Host "======================================="

$CURRENT_SCRIPT_PATH = $MyInvocation.MyCommand.Path
$CURRENT_DIR = Split-Path $CURRENT_SCRIPT_PATH -Parent
# 回溯获取工作目录 (向上4级)
$WORK_DIR = Split-Path (Split-Path (Split-Path (Split-Path $CURRENT_DIR -Parent) -Parent) -Parent) -Parent
$UPGRADE_DIR = Join-Path $CURRENT_DIR "upgrade"

Write-Host "[INFO] 脚本路径:`n$CURRENT_SCRIPT_PATH"
Write-Host "[INFO] 工作目录:`n$WORK_DIR"
Write-Host "[INFO] 升级目录:`n$UPGRADE_DIR"

# =======================================
# 3. 版本校验 (必须 >= REQUIRED_VERSION)
# =======================================
Write-Host "`n======================================="
Write-Host "校验升级版本"
Write-Host "======================================="

function Compare-Version {
    param([string]$v1, [string]$v2)
    # 去掉前缀 v 或 V
    $v1 = $v1 -replace '^[vV]', ''
    $v2 = $v2 -replace '^[vV]', ''
    $parts1 = $v1 -split '\.'
    $parts2 = $v2 -split '\.'
    for ($i = 0; $i -lt [Math]::Max($parts1.Length, $parts2.Length); $i++) {
        $num1 = if ($i -lt $parts1.Length) { [int]$parts1[$i] } else { 0 }
        $num2 = if ($i -lt $parts2.Length) { [int]$parts2[$i] } else { 0 }
        if ($num1 -gt $num2) { return $true }
        if ($num1 -lt $num2) { return $false }
    }
    return $true # 相等
}

if (-not (Compare-Version $Version $REQUIRED_VERSION)) {
    Write-Host "[ERROR] 版本号 $Version 必须大于等于 $REQUIRED_VERSION" -ForegroundColor Red
    exit 1
}
Write-Host "[INFO] 版本校验通过"

# =======================================
# 4. 清理历史缓存
# =======================================
Write-Host "`n======================================="
Write-Host "清理历史缓存"
Write-Host "======================================="

$collectorPath = Join-Path $WORK_DIR "plugins\collector"
if (Test-Path $collectorPath) {
    Get-ChildItem $collectorPath -Directory | ForEach-Object {
        $backupPath = Join-Path $_.FullName "backup"
        if (Test-Path $backupPath) {
            Remove-Item "$backupPath\*" -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
}
Remove-Item "$WORK_DIR\plugins\*\*.tar" -Force -ErrorAction SilentlyContinue
Remove-Item "$WORK_DIR\plugins\*\*.checksum" -Force -ErrorAction SilentlyContinue
Write-Host "[INFO] 历史缓存清理完成"

# =======================================
# 5. 解析下载服务器地址
# =======================================
Write-Host "`n======================================="
Write-Host "解析下载服务器地址"
Write-Host "======================================="

$configFile = Join-Path $WORK_DIR "kernel.toml"
if (-not (Test-Path $configFile)) {
    Write-Host "[ERROR] 未找到配置文件:`n$configFile" -ForegroundColor Red
    exit 1
}

$configContent = Get-Content $configFile -Raw
if ($configContent -match '(?i)http_address\s*=\s*"([^"]+)"') {
    $FINAL_HOST = $matches[1] -replace '[\[\]\s]', ''
} else {
    Write-Host "[ERROR] 无法解析 http_address" -ForegroundColor Red
    exit 1
}
Write-Host "[INFO] 下载服务器:`n$FINAL_HOST"

# =======================================
# 6. 初始化升级目录
# =======================================
Write-Host "`n======================================="
Write-Host "初始化升级目录"
Write-Host "======================================="

$BACKUP_DIR = Join-Path $UPGRADE_DIR "backup"
$DOWNLOAD_DIR = Join-Path $UPGRADE_DIR "download"
$BACKUP_SHADOW_DIR = Join-Path $BACKUP_DIR "plugins\shadow"

# 创建目录
foreach ($dir in @($BACKUP_SHADOW_DIR, $DOWNLOAD_DIR)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}
Write-Host "[INFO] 初始化完成"

# =======================================
# 7. 检测系统架构
# =======================================
Write-Host "`n======================================="
Write-Host "检测系统架构"
Write-Host "======================================="

$TARGET_ARCH = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
Write-Host "[INFO] 当前系统架构: $TARGET_ARCH"

# =======================================
# 8. 构造下载地址和文件名
# =======================================
$URL = "https://${FINAL_HOST}/api/console/files/download?file_name=agent&os=windows&arch=$TARGET_ARCH&version=$Version&type=package&agent=true"
$FILE_NAME = "agent_windows_${TARGET_ARCH}_${Version}.tar"

# =======================================
# 9. 备份当前文件
# =======================================
Write-Host "`n======================================="
Write-Host "备份当前文件"
Write-Host "======================================="

$filesToBackup = @(
    @{Source = Join-Path $WORK_DIR "kernel.exe"; Dest = $BACKUP_DIR},
    @{Source = Join-Path $WORK_DIR "kernel.toml"; Dest = $BACKUP_DIR},
    @{Source = Join-Path $WORK_DIR "state.toml"; Dest = $BACKUP_DIR},
    @{Source = Join-Path $WORK_DIR "plugins\shadow\shadow.exe"; Dest = $BACKUP_SHADOW_DIR}
)
foreach ($item in $filesToBackup) {
    if (Test-Path $item.Source) {
        Copy-Item -Path $item.Source -Destination $item.Dest -Force -ErrorAction SilentlyContinue
    }
}
Write-Host "[INFO] 文件备份完成"

# =======================================
# 10. tar 工具配置
# =======================================
$INSTALLER = Join-Path $DOWNLOAD_DIR "windows_tar_tool.exe"
$GNU_BIN_PATH = "C:\Program Files (x86)\GnuWin32\bin"
$TAR_EXE = Join-Path $GNU_BIN_PATH "tar.exe"
$TARGET_TAR = Join-Path $DOWNLOAD_DIR $FILE_NAME
$TAR_TOOL_URL = "https://${FINAL_HOST}/api/console/files/download?file_name=windows+tar+tool&os=windows&arch=amd64&version=v1.0.0&type=package&agent=false"

# =======================================
# 11. 下载 tar 工具
# =======================================
Write-Host "`n======================================="
Write-Host "下载 tar 解压工具"
Write-Host "======================================="

try {
    Invoke-WebRequest -Uri $TAR_TOOL_URL -OutFile $INSTALLER -UseBasicParsing
} catch {
    Write-Host "[ERROR] tar 工具下载失败: $_" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $INSTALLER)) {
    Write-Host "[ERROR] tar 工具下载失败 (文件未生成)" -ForegroundColor Red
    exit 1
}
Write-Host "[INFO] tar 工具下载成功"

# =======================================
# 12. 安装 tar 工具 (静默安装)
# =======================================
Write-Host "`n======================================="
Write-Host "安装 tar 解压工具"
Write-Host "======================================="

$process = Start-Process -FilePath $INSTALLER -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART" -NoNewWindow -Wait -PassThru
if ($process.ExitCode -ne 0 -or -not (Test-Path $TAR_EXE)) {
    Write-Host "[ERROR] tar 工具安装失败" -ForegroundColor Red
    exit 1
}
Write-Host "[INFO] tar 工具安装完成"

# =======================================
# 13. 下载升级包
# =======================================
Write-Host "`n======================================="
Write-Host "下载升级包"
Write-Host "======================================="
Write-Host "[INFO] 下载地址:`n$URL"

try {
    Invoke-WebRequest -Uri $URL -OutFile $TARGET_TAR -UseBasicParsing
} catch {
    Write-Host "[ERROR] 升级包下载失败: $_" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $TARGET_TAR) -or (Get-Item $TARGET_TAR).Length -eq 0) {
    Write-Host "[ERROR] 升级包下载失败或大小为0" -ForegroundColor Red
    Remove-Item $TARGET_TAR -Force -ErrorAction SilentlyContinue
    exit 1
}
Write-Host "[INFO] 升级包下载完成"

# =======================================
# 14. 解压升级包
# =======================================
Write-Host "`n======================================="
Write-Host "解压升级包"
Write-Host "======================================="

$tempExtract = Join-Path $DOWNLOAD_DIR "temp_$([System.IO.Path]::GetRandomFileName())"
New-Item -ItemType Directory -Path $tempExtract -Force | Out-Null

Push-Location $DOWNLOAD_DIR
try {
    & $TAR_EXE --force-local -xf $FILE_NAME -C $tempExtract
    if ($LASTEXITCODE -ne 0) { throw "tar 解压失败" }
} catch {
    Write-Host "[ERROR] 升级包解压失败: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host "[INFO] 升级包解压完成"

# =======================================
# 15. 禁止服务自动恢复
# =======================================
Write-Host "`n======================================="
Write-Host "禁止服务自动恢复"
Write-Host "======================================="

& sc.exe failure kernel reset= 0 actions= "" | Out-Null
& sc.exe config kernel start= demand | Out-Null
Write-Host "[INFO] 已关闭自动恢复策略"
Write-Host "[INFO] 已关闭自动启动"

# =======================================
# 16. 停止 shadow.exe 和 kernel.exe
# =======================================
Write-Host "`n======================================="
Write-Host "停止 shadow.exe"
Write-Host "======================================="

Stop-Process -Name "shadow" -Force -ErrorAction SilentlyContinue
# 等待进程退出
do { Start-Sleep -Seconds 2 } while (Get-Process -Name "shadow" -ErrorAction SilentlyContinue)
Write-Host "[INFO] shadow.exe 已退出"

Write-Host "`n======================================="
Write-Host "停止 kernel.exe"
Write-Host "======================================="

Stop-Process -Name "kernel" -Force -ErrorAction SilentlyContinue
do { Start-Sleep -Seconds 2 } while (Get-Process -Name "kernel" -ErrorAction SilentlyContinue)
Write-Host "[INFO] kernel.exe 已退出"

# =======================================
# 17. 替换 kernel.exe
# =======================================
Write-Host "`n======================================="
Write-Host "替换 kernel.exe"
Write-Host "======================================="

$srcKernel = Join-Path $tempExtract "kernel.exe"
if (-not (Test-Path $srcKernel)) {
    Write-Host "[ERROR] 升级包中不存在 kernel.exe" -ForegroundColor Red
    exit 1
}
Copy-Item -Path $srcKernel -Destination (Join-Path $WORK_DIR "kernel.exe") -Force
Write-Host "[INFO] kernel.exe 替换完成"

# =======================================
# 18. 替换 shadow.exe 并生成 config.yaml
# =======================================
Write-Host "`n======================================="
Write-Host "替换 shadow.exe"
Write-Host "======================================="

$srcShadow = Join-Path $tempExtract "plugins\shadow\shadow.exe"
if (-not (Test-Path $srcShadow)) {
    Write-Host "[ERROR] 升级包中不存在 shadow.exe" -ForegroundColor Red
    exit 1
}
$shadowDir = Join-Path $WORK_DIR "plugins\shadow"
if (-not (Test-Path $shadowDir)) {
    New-Item -ItemType Directory -Path $shadowDir -Force | Out-Null
}
Copy-Item -Path $srcShadow -Destination (Join-Path $shadowDir "shadow.exe") -Force

# 创建 config.yaml
$configYaml = @"
monitor:
    interval: 60
kernel:
    wait_time: 300
    interval: 5
"@
Set-Content -Path (Join-Path $shadowDir "config.yaml") -Value $configYaml -Encoding UTF8
Write-Host "[INFO] shadow.exe 替换完成"

# =======================================
# 19. 恢复 Windows 服务配置
# =======================================
Write-Host "`n======================================="
Write-Host "恢复 Windows 服务配置"
Write-Host "======================================="

& sc.exe config kernel start= auto | Out-Null
& sc.exe failure kernel reset= 86400 actions= restart/60000/restart/60000/restart/60000 | Out-Null
Write-Host "[INFO] 已恢复自动启动"
Write-Host "[INFO] 已恢复失败自动恢复策略"

# =======================================
# 20. 启动 kernel 服务
# =======================================
Write-Host "`n======================================="
Write-Host "启动 kernel 服务"
Write-Host "======================================="

try {
    Start-Service -Name "kernel" -ErrorAction Stop
} catch {
    Write-Host "[ERROR] kernel 服务启动失败: $_" -ForegroundColor Red
    exit 1
}
Write-Host "[INFO] kernel 服务启动成功"
Start-Sleep -Seconds 5

# =======================================
# 21. 查看服务状态
# =======================================
Write-Host "`n======================================="
Write-Host "查看服务状态"
Write-Host "======================================="
Get-Service -Name "kernel" | Format-List Name, Status, StartType

# =======================================
# 22. 验证版本输出
# =======================================
Write-Host "`n======================================="
Write-Host "验证版本输出"
Write-Host "======================================="

$kernelExe = Join-Path $WORK_DIR "kernel.exe"
if (Test-Path $kernelExe) {
    Write-Host "`n[kernel.exe -version]"
    & $kernelExe -version
}
$shadowExe = Join-Path $WORK_DIR "plugins\shadow\shadow.exe"
if (Test-Path $shadowExe) {
    Write-Host "`n[shadow.exe --version]"
    & $shadowExe --version
}

# =======================================
# 23. 清理临时文件
# =======================================
Write-Host "`n======================================="
Write-Host "清理临时文件"
Write-Host "======================================="

if (Test-Path $tempExtract) {
    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "[INFO] 临时文件清理完成"

# =======================================
# 24. 升级结束
# =======================================
Write-Host "`n======================================="
Write-Host "升级完成"
Write-Host "======================================="
Write-Host "[INFO] 当前版本: $Version"
Write-Host "[INFO] kernel 服务运行正常"
Write-Host ""