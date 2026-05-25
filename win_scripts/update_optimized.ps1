<#
.SYNOPSIS
    Windows Agent 升级脚本 (PowerShell 5.1)

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
        - 优先使用系统自带 tar，不存在时下载 GnuWin32 tar
        - 不修改 PATH 环境变量
        - 自动关闭服务恢复策略
        - 支持 Windows Server 2016
        - 支持升级失败自动回滚
        - 支持下载失败自动重试
        - 支持完整会话日志记录

    注意：
        - 脚本文件编码保存为 UTF-8 with BOM
        - 必须使用管理员权限运行

.PARAMETER --version
    目标升级版本号，格式如 v1.4.5

.PARAMETER --retry-count
    下载失败重试次数，默认 3

.PARAMETER --log-transcript
    是否启用会话日志记录（Start-Transcript），默认启用

.PARAMETER --help
    显示帮助信息

.EXAMPLE
    .\update_optimized.ps1 --version v1.4.5
    .\update_optimized.ps1 --version v1.4.5 --retry-count 5
    .\update_optimized.ps1 --version v1.4.5 --no-log-transcript
#>

$ErrorActionPreference = "Stop"

function Show-Help {
    Write-Host @"
用法:
    .\update_optimized.ps1 --version <版本号> [选项]

参数:
    --version <版本号>       目标升级版本号，格式如 v1.4.5 (必填)
    --retry-count <次数>     下载失败重试次数，默认 3
    --skip-cert-check        跳过 HTTPS 证书校验 (默认启用)
    --no-skip-cert-check     启用 HTTPS 证书校验
    --log-transcript         启用会话日志记录 (默认启用)
    --no-log-transcript      禁用会话日志记录
    --help                   显示此帮助信息

示例:
    .\update_optimized.ps1 --version v1.4.5
    .\update_optimized.ps1 --version v1.4.5 --retry-count 5
    .\update_optimized.ps1 --version v1.4.5 --no-log-transcript
    .\update_optimized.ps1 --version v1.4.5 --no-skip-cert-check
"@
    exit 0
}

$Version = ""
$RetryCount = 3
$SkipCertCheck = $true
$LogTranscript = $true

$i = 0
while ($i -lt $args.Length) {
    switch ($args[$i]) {
        "--version" {
            if (($i + 1) -ge $args.Length -or $args[$i + 1] -match "^--") {
                Write-Host "[ERROR] --version 需要指定版本号" -ForegroundColor Red
                exit 1
            }
            $i++
            $Version = $args[$i]
        }
        "--retry-count" {
            if (($i + 1) -ge $args.Length -or $args[$i + 1] -match "^--") {
                Write-Host "[ERROR] --retry-count 需要指定次数" -ForegroundColor Red
                exit 1
            }
            $i++
            $RetryCount = [int]$args[$i]
        }
        "--log-transcript" {
            $LogTranscript = $true
        }
        "--no-log-transcript" {
            $LogTranscript = $false
        }
        "--skip-cert-check" {
            $SkipCertCheck = $true
        }
        "--no-skip-cert-check" {
            $SkipCertCheck = $false
        }
        "--help" {
            Show-Help
        }
        default {
            Write-Host "[ERROR] 未知参数: $($args[$i])" -ForegroundColor Red
            Write-Host "使用 --help 查看帮助信息"
            exit 1
        }
    }
    $i++
}

if ($Version -eq "") {
    Write-Host "[ERROR] 缺少 --version 参数" -ForegroundColor Red
    Write-Host "使用 --help 查看帮助信息"
    exit 1
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Host "[ERROR] 请以管理员身份运行此脚本" -ForegroundColor Red
    exit 1
}

chcp 65001 >$null 2>&1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($SkipCertCheck) {
    [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
}

$REQUIRED_VERSION = "v1.4.4"
$PROCESS_WAIT_TIMEOUT = 30
$DOWNLOAD_RETRY_INTERVAL = 5

$CURRENT_SCRIPT_PATH = $MyInvocation.MyCommand.Path
if (-not $CURRENT_SCRIPT_PATH) {
    $CURRENT_SCRIPT_PATH = $PSCommandPath
}
if (-not $CURRENT_SCRIPT_PATH) {
    Write-Host "[ERROR] 无法确定脚本路径，请使用完整路径运行脚本" -ForegroundColor Red
    exit 1
}
$CURRENT_DIR = Split-Path $CURRENT_SCRIPT_PATH -Parent
$PARENT_DIR = Join-Path $CURRENT_DIR "..\..\..\.."
if (Test-Path $PARENT_DIR) {
    $WORK_DIR = (Resolve-Path $PARENT_DIR).Path
} else {
    $WORK_DIR = [System.IO.Path]::GetFullPath($PARENT_DIR)
}
$UPGRADE_DIR = Join-Path $CURRENT_DIR "upgrade"
$BACKUP_DIR = Join-Path $UPGRADE_DIR "backup"
$DOWNLOAD_DIR = Join-Path $UPGRADE_DIR "download"
$BACKUP_SHADOW_DIR = Join-Path $BACKUP_DIR "plugins\shadow"
$LOG_DIR = Join-Path $UPGRADE_DIR "logs"

$tempExtract = $null
$transcriptStarted = $false

function Write-Step {
    param([string]$Title)
    Write-Host "`n=======================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
}

function Compare-SemanticVersion {
    param([string]$v1, [string]$v2)
    $v1 = $v1 -replace '^[vV]', ''
    $v2 = $v2 -replace '^[vV]', ''
    try {
        return [version]$v1 -ge [version]$v2
    } catch {
        $p1 = $v1 -split '\.'
        $p2 = $v2 -split '\.'
        for ($i = 0; $i -lt [Math]::Max($p1.Length, $p2.Length); $i++) {
            $n1 = if ($i -lt $p1.Length) { [int]$p1[$i] } else { 0 }
            $n2 = if ($i -lt $p2.Length) { [int]$p2[$i] } else { 0 }
            if ($n1 -gt $n2) { return $true }
            if ($n1 -lt $n2) { return $false }
        }
        return $true
    }
}

function Stop-ProcessWithTimeout {
    param(
        [string]$Name,
        [int]$TimeoutSeconds = 30
    )
    $proc = Get-Process -Name $Name -ErrorAction SilentlyContinue
    if (-not $proc) {
        Write-Host "[INFO] ${Name}.exe 未运行"
        return
    }
    Stop-Process -Name $Name -Force -ErrorAction SilentlyContinue
    $elapsed = 0
    while ((Get-Process -Name $Name -ErrorAction SilentlyContinue) -and ($elapsed -lt $TimeoutSeconds)) {
        Start-Sleep -Seconds 2
        $elapsed += 2
        Write-Host "[INFO] 等待 ${Name}.exe 退出... ($elapsed/${TimeoutSeconds}s)"
    }
    if (Get-Process -Name $Name -ErrorAction SilentlyContinue) {
        Write-Host "[WARN] ${Name}.exe 在 ${TimeoutSeconds}s 内未退出，强制终止" -ForegroundColor Yellow
        Stop-Process -Name $Name -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
    Write-Host "[INFO] ${Name}.exe 已退出"
}

function Invoke-SecureDownload {
    param(
        [string]$Url,
        [string]$OutFile,
        [int]$MaxRetries = $RetryCount
    )
    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        $attempt++
        try {
            if ($attempt -gt 1) {
                Write-Host "[INFO] 第 ${attempt}/${MaxRetries} 次重试下载..."
                Start-Sleep -Seconds $DOWNLOAD_RETRY_INTERVAL
            }
            $client = New-Object Net.WebClient
            $client.DownloadFile($Url, $OutFile)
            if (-not (Test-Path $OutFile) -or (Get-Item $OutFile).Length -eq 0) {
                Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
                throw "下载文件为空或不存在"
            }
            $sizeMB = [Math]::Round((Get-Item $OutFile).Length / 1MB, 2)
            Write-Host "[INFO] 下载成功 (大小: ${sizeMB} MB)"
            return $true
        } catch {
            Write-Host "[WARN] 第 ${attempt} 次下载失败: $_" -ForegroundColor Yellow
        }
    }
    Write-Host "[ERROR] 下载失败，已重试 ${MaxRetries} 次" -ForegroundColor Red
    return $false
}

function Restore-Backup {
    param(
        [string]$BackupRoot,
        [string]$TargetRoot
    )
    Write-Host "[INFO] 正在回滚..." -ForegroundColor Yellow
    if (-not (Test-Path $BackupRoot)) {
        Write-Host "[WARN] 备份目录不存在，无法回滚" -ForegroundColor Yellow
        return
    }
    $backupItems = @(
        @{Relative = "kernel.exe"; Dest = $TargetRoot},
        @{Relative = "kernel.toml"; Dest = $TargetRoot},
        @{Relative = "state.toml"; Dest = $TargetRoot},
        @{Relative = "plugins\shadow\shadow.exe"; Dest = (Join-Path $TargetRoot "plugins\shadow")}
    )
    foreach ($item in $backupItems) {
        $src = Join-Path $BackupRoot $item.Relative
        if (Test-Path $src) {
            if (-not (Test-Path $item.Dest)) {
                New-Item -ItemType Directory -Path $item.Dest -Force | Out-Null
            }
            Copy-Item -Path $src -Destination $item.Dest -Force -ErrorAction SilentlyContinue
            Write-Host "[INFO] 已恢复: $($item.Relative)"
        }
    }
}

function Find-TarExecutable {
    $gnuTar = Join-Path "C:\Program Files (x86)\GnuWin32\bin" "tar.exe"
    if (Test-Path $gnuTar) {
        Write-Host "[INFO] 检测到已安装 GnuWin32 tar: $gnuTar"
        return $gnuTar
    }
    return $null
}

trap {
    Write-Host "`n[FATAL] 未捕获的异常: $_" -ForegroundColor Red
    if ($tempExtract -and (Test-Path $tempExtract)) {
        Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
    break
}

try {

    if ($LogTranscript) {
        if (-not (Test-Path $LOG_DIR)) {
            New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
        }
        $logFile = Join-Path $LOG_DIR "update_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        try {
            Start-Transcript -Path $logFile -Append -Force | Out-Null
            $transcriptStarted = $true
            Write-Host "[INFO] 会话日志: $logFile"
        } catch {
            Write-Host "[WARN] 无法启动日志记录: $_" -ForegroundColor Yellow
        }
    }

    # =======================================
    # 初始化环境
    # =======================================
    Write-Step "初始化运行环境"

    Write-Host "[INFO] 脚本路径: $CURRENT_SCRIPT_PATH"
    Write-Host "[INFO] 工作目录: $WORK_DIR"
    Write-Host "[INFO] 升级目录: $UPGRADE_DIR"
    Write-Host "[INFO] PowerShell 版本: $($PSVersionTable.PSVersion)"
    Write-Host "[INFO] 操作系统: $([Environment]::OSVersion.VersionString)"

    # =======================================
    # 版本校验
    # =======================================
    Write-Step "校验升级版本"

    if (-not (Compare-SemanticVersion $Version $REQUIRED_VERSION)) {
        Write-Host "[ERROR] 版本号 $Version 必须大于等于 $REQUIRED_VERSION" -ForegroundColor Red
        exit 1
    }
    Write-Host "[INFO] 版本校验通过: $Version >= $REQUIRED_VERSION"

    # =======================================
    # 清理历史缓存
    # =======================================
    Write-Step "清理历史缓存"

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
    # 解析下载服务器地址
    # =======================================
    Write-Step "解析下载服务器地址"

    $configFile = Join-Path $WORK_DIR "kernel.toml"
    if (-not (Test-Path $configFile)) {
        Write-Host "[ERROR] 未找到配置文件: $configFile" -ForegroundColor Red
        exit 1
    }

    $FINAL_HOST = $null
    $configContent = Get-Content $configFile -ErrorAction SilentlyContinue
    foreach ($line in $configContent) {
        if ($line -match '(?i)http_address') {
            $parts = $line -split '=', 2
            if ($parts.Length -ge 2) {
                $val = $parts[1]
                $val = $val -replace '"', ''
                $val = $val -replace "'", ''
                $val = $val -replace '\s', ''
                $val = $val -replace '\[', ''
                $val = $val -replace '\]', ''
                $val = ($val -split ',')[0]
                $FINAL_HOST = $val
            }
            break
        }
    }
    if (-not $FINAL_HOST) {
        Write-Host "[ERROR] 无法解析 http_address" -ForegroundColor Red
        Write-Host "[DEBUG] 配置文件: $configFile" -ForegroundColor DarkGray
        Write-Host "[DEBUG] 匹配行内容:" -ForegroundColor DarkGray
        foreach ($line in $configContent) {
            if ($line -match '(?i)http_address') {
                Write-Host "  $line" -ForegroundColor DarkGray
            }
        }
        exit 1
    }
    Write-Host "[INFO] 下载服务器: $FINAL_HOST"

    # =======================================
    # 初始化升级目录
    # =======================================
    Write-Step "初始化升级目录"

    foreach ($dir in @($BACKUP_SHADOW_DIR, $DOWNLOAD_DIR)) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    Write-Host "[INFO] 初始化完成"

    # =======================================
    # 检测系统架构
    # =======================================
    Write-Step "检测系统架构"

    $TARGET_ARCH = "amd64"
    Write-Host "[INFO] 当前系统架构: $TARGET_ARCH"

    # =======================================
    # 构造下载地址
    # =======================================
    $URL = "https://${FINAL_HOST}/api/console/files/download?file_name=agent&os=windows&arch=$TARGET_ARCH&version=$Version&type=package&agent=true"
    $FILE_NAME = "agent_windows_${TARGET_ARCH}_${Version}.tar"

    # =======================================
    # 备份当前文件
    # =======================================
    Write-Step "备份当前文件"

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
    # tar 工具检测与安装
    # =======================================
    $TAR_EXE = Find-TarExecutable

    if (-not $TAR_EXE) {
        Write-Step "下载 tar 解压工具"

        $INSTALLER = Join-Path $DOWNLOAD_DIR "windows_tar_tool.exe"
        $GNU_BIN_PATH = "C:\Program Files (x86)\GnuWin32\bin"
        $TAR_TOOL_URL = "https://${FINAL_HOST}/api/console/files/download?file_name=windows+tar+tool&os=windows&arch=amd64&version=v1.0.0&type=package&agent=false"

        if (-not (Invoke-SecureDownload -Url $TAR_TOOL_URL -OutFile $INSTALLER)) {
            exit 1
        }

        Write-Step "安装 tar 解压工具"
        $proc = Start-Process -FilePath $INSTALLER -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART" -NoNewWindow -Wait -PassThru
        if ($proc.ExitCode -ne 0 -or -not (Test-Path (Join-Path $GNU_BIN_PATH "tar.exe"))) {
            Write-Host "[ERROR] tar 工具安装失败" -ForegroundColor Red
            exit 1
        }
        $TAR_EXE = Join-Path $GNU_BIN_PATH "tar.exe"
        Write-Host "[INFO] tar 工具安装完成"
    }

    # =======================================
    # 下载升级包
    # =======================================
    Write-Step "下载升级包"
    Write-Host "[INFO] 下载地址: $URL"

    $TARGET_TAR = Join-Path $DOWNLOAD_DIR $FILE_NAME
    if (-not (Invoke-SecureDownload -Url $URL -OutFile $TARGET_TAR)) {
        exit 1
    }

    # =======================================
    # 解压升级包
    # =======================================
    Write-Step "解压升级包"

    $tempExtractName = "temp_$([System.IO.Path]::GetRandomFileName())"
    $tempExtract = Join-Path $DOWNLOAD_DIR $tempExtractName
    New-Item -ItemType Directory -Path $tempExtract -Force | Out-Null

    Push-Location $DOWNLOAD_DIR
    try {
        & $TAR_EXE --force-local -xf $FILE_NAME -C $tempExtractName
        if ($LASTEXITCODE -ne 0) { throw "tar 退出码: $LASTEXITCODE" }
    } catch {
        Write-Host "[ERROR] 升级包解压失败: $_" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Pop-Location
    Write-Host "[INFO] 升级包解压完成"

    # =======================================
    # 禁止服务自动恢复
    # =======================================
    Write-Step "禁止服务自动恢复"

    & sc.exe failure kernel reset= 0 actions= "" 2>$null | Out-Null
    & sc.exe config kernel start= demand 2>$null | Out-Null
    Write-Host "[INFO] 已关闭自动恢复策略"
    Write-Host "[INFO] 已关闭自动启动"

    # =======================================
    # 停止进程
    # =======================================
    Write-Step "停止 shadow.exe"
    Stop-ProcessWithTimeout -Name "shadow" -TimeoutSeconds $PROCESS_WAIT_TIMEOUT

    Write-Step "停止 kernel.exe"
    Stop-ProcessWithTimeout -Name "kernel" -TimeoutSeconds $PROCESS_WAIT_TIMEOUT

    # =======================================
    # 替换 kernel.exe
    # =======================================
    Write-Step "替换 kernel.exe"

    $srcKernel = Join-Path $tempExtract "kernel.exe"
    if (-not (Test-Path $srcKernel)) {
        Write-Host "[ERROR] 升级包中不存在 kernel.exe" -ForegroundColor Red
        Restore-Backup -BackupRoot $BACKUP_DIR -TargetRoot $WORK_DIR
        exit 1
    }
    Copy-Item -Path $srcKernel -Destination (Join-Path $WORK_DIR "kernel.exe") -Force
    Write-Host "[INFO] kernel.exe 替换完成"

    # =======================================
    # 替换 shadow.exe 并生成 config.yaml
    # =======================================
    Write-Step "替换 shadow.exe"

    $srcShadow = Join-Path $tempExtract "plugins\shadow\shadow.exe"
    if (-not (Test-Path $srcShadow)) {
        Write-Host "[ERROR] 升级包中不存在 shadow.exe" -ForegroundColor Red
        Restore-Backup -BackupRoot $BACKUP_DIR -TargetRoot $WORK_DIR
        exit 1
    }
    $shadowDir = Join-Path $WORK_DIR "plugins\shadow"
    if (-not (Test-Path $shadowDir)) {
        New-Item -ItemType Directory -Path $shadowDir -Force | Out-Null
    }
    Copy-Item -Path $srcShadow -Destination (Join-Path $shadowDir "shadow.exe") -Force

    $configYaml = @"
monitor:
    interval: 60
kernel:
    wait_time: 300
    interval: 5
"@
    [System.IO.File]::WriteAllText((Join-Path $shadowDir "config.yaml"), $configYaml, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "[INFO] shadow.exe 替换完成"

    # =======================================
    # 恢复 Windows 服务配置
    # =======================================
    Write-Step "恢复 Windows 服务配置"

    & sc.exe config kernel start= auto 2>$null | Out-Null
    & sc.exe failure kernel reset= 86400 actions= restart/60000/restart/60000/restart/60000 2>$null | Out-Null
    Write-Host "[INFO] 已恢复自动启动"
    Write-Host "[INFO] 已恢复失败自动恢复策略"

    # =======================================
    # 启动 kernel 服务
    # =======================================
    Write-Step "启动 kernel 服务"

    try {
        Start-Service -Name "kernel" -ErrorAction Stop
    } catch {
        Write-Host "[ERROR] kernel 服务启动失败: $_" -ForegroundColor Red
        Write-Host "[INFO] 尝试回滚..." -ForegroundColor Yellow
        Stop-ProcessWithTimeout -Name "kernel" -TimeoutSeconds 10
        Restore-Backup -BackupRoot $BACKUP_DIR -TargetRoot $WORK_DIR
        & sc.exe config kernel start= auto 2>$null | Out-Null
        & sc.exe failure kernel reset= 86400 actions= restart/60000/restart/60000/restart/60000 2>$null | Out-Null
        Start-Service -Name "kernel" -ErrorAction SilentlyContinue
        exit 1
    }
    Write-Host "[INFO] kernel 服务启动成功"
    Start-Sleep -Seconds 5

    # =======================================
    # 查看服务状态
    # =======================================
    Write-Step "查看服务状态"

    $svc = Get-Service -Name "kernel" -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Host "[INFO] kernel 服务状态: $($svc.Status)"
        Write-Host "[INFO] kernel 启动类型: $($svc.StartType)"
    }

    # =======================================
    # 验证版本输出
    # =======================================
    Write-Step "验证版本输出"

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
    # 清理临时文件
    # =======================================
    Write-Step "清理临时文件"

    if ($tempExtract -and (Test-Path $tempExtract)) {
        Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "[INFO] 临时文件清理完成"

    # =======================================
    # 升级结束
    # =======================================
    Write-Step "升级完成"

    Write-Host "[INFO] 当前版本: $Version" -ForegroundColor Green
    Write-Host "[INFO] kernel 服务运行正常" -ForegroundColor Green
    Write-Host ""

} finally {
    if ($tempExtract -and (Test-Path $tempExtract)) {
        Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
}
