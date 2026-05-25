@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
cls

:: =======================================
:: Windows Agent Upgrade Script
::
:: 功能:
::   1. 校验升级版本号
::   2. 自动解析下载服务器地址
::   3. 下载并安装 tar 解压工具
::   4. 下载 agent 升级包
::   5. 解压升级包
::   6. 停止 kernel/shadow 进程
::   7. 替换 kernel.exe 与 shadow.exe
::   8. 恢复 Windows 服务配置
::   9. 启动 kernel 服务
::
:: 特点:
::   - 静默执行
::   - 不依赖系统自带 tar
::   - 不修改 PATH 环境变量
::   - 自动关闭服务恢复策略
::   - 支持 Windows Server 2016
::
:: 注意:
::   - 文件编码必须为 UTF-8 with BOM
::   - 必须使用管理员权限运行
:: =======================================



:: =======================================
:: 1. 基础变量定义
:: =======================================

set "VERSION="
set "REQUIRED_VERSION=v1.4.4"



:: =======================================
:: 2. 参数解析
:: =======================================

if "%~1"=="" goto usage

:parse_args

if "%~1"=="" goto env_init

if /i "%~1"=="--version" (
    set "VERSION=%~2"
    shift
    shift
    goto parse_args
)

if /i "%~1"=="-h" goto usage
if /i "%~1"=="--help" goto usage

echo [ERROR] 未知参数: %1
goto usage



:: =======================================
:: 帮助信息
:: =======================================

:usage

echo.
echo 用法:
echo     %~nx0 --version [agent版本号]
echo.
echo 示例:
echo     %~nx0 --version v1.4.5
echo.

exit /b 0



:: =======================================
:: 3. 初始化环境
:: =======================================

:env_init

echo.
echo =======================================
echo 初始化运行环境
echo =======================================

:: 当前脚本路径
set "CURRENT_SCRIPT_PATH=%~f0"

:: 当前脚本目录
set "CURRENT_DIR=%~dp0"
set "CURRENT_DIR=%CURRENT_DIR:~0,-1%"

:: 回溯获取工作目录
for %%I in ("%CURRENT_DIR%\..\..\..\..") do (
    set "WORK_DIR=%%~fI"
)

:: 升级目录
set "UPGRADE_DIR=%CURRENT_DIR%\upgrade"

echo [INFO] 脚本路径:
echo(%CURRENT_SCRIPT_PATH%

echo [INFO] 工作目录:
echo(%WORK_DIR%

echo [INFO] 升级目录:
echo(%UPGRADE_DIR%



:: =======================================
:: 4. 参数检查
:: =======================================

if "%VERSION%"=="" (
    echo [ERROR] 缺少 --version 参数
    exit /b 1
)



:: =======================================
:: 5. 版本校验
:: =======================================

echo.
echo =======================================
echo 校验升级版本
echo =======================================

set "v1=%VERSION%"
if "%v1:~0,1%"=="v" set "v1=%v1:~1%"
if "%v1:~0,1%"=="V" set "v1=%v1:~1%"

set "v2=%REQUIRED_VERSION%"
if "%v2:~0,1%"=="v" set "v2=%v2:~1%"

for /f "tokens=1-3 delims=." %%a in ("%v1%") do (
    set "v1_major=%%a"
    set "v1_minor=%%b"
    set "v1_patch=%%c"
)

for /f "tokens=1-3 delims=." %%a in ("%v2%") do (
    set "v2_major=%%a"
    set "v2_minor=%%b"
    set "v2_patch=%%c"
)

set "pass=0"

if %v1_major% GTR %v2_major% set "pass=1"

if %v1_major% EQU %v2_major% (
    if %v1_minor% GTR %v2_minor% set "pass=1"

    if %v1_minor% EQU %v2_minor% (
        if %v1_patch% GEQ %v2_patch% set "pass=1"
    )
)

if "%pass%"=="0" (
    echo [ERROR] 版本号 %VERSION% 必须大于等于 %REQUIRED_VERSION%
    exit /b 1
)

echo [INFO] 版本校验通过



:: =======================================
:: 6. 清理历史缓存
:: =======================================

echo.
echo =======================================
echo 清理历史缓存
echo =======================================

if exist "%WORK_DIR%\plugins\collector" (
    for /d %%d in ("%WORK_DIR%\plugins\collector\*") do (
        if exist "%%d\backup" (
            del /q /s /f "%%d\backup\*" >nul 2>&1
        )
    )
)

del /q /f "%WORK_DIR%\plugins\*\*.tar" >nul 2>&1
del /q /f "%WORK_DIR%\plugins\*\*.checksum" >nul 2>&1

echo [INFO] 历史缓存清理完成



:: =======================================
:: 7. 解析下载服务器地址
:: =======================================

echo.
echo =======================================
echo 解析下载服务器地址
echo =======================================

set "CONFIG_FILE=%WORK_DIR%\kernel.toml"

if not exist "%CONFIG_FILE%" (
    echo [ERROR] 未找到配置文件:
    echo(%CONFIG_FILE%
    exit /b 1
)

set "FINAL_HOST="

for /f "tokens=2 delims==" %%i in ('findstr /i "http_address" "%CONFIG_FILE%"') do (

    set "line=%%i"

    set "line=!line:"=!"
    set "line=!line: =!"
    set "line=!line:[=!"
    set "line=!line:]=!"

    for /f "tokens=1 delims=," %%a in ("!line!") do (
        set "FINAL_HOST=%%a"
    )
)

if "%FINAL_HOST%"=="" (
    echo [ERROR] 无法解析 http_address
    exit /b 1
)

echo [INFO] 下载服务器:
echo(%FINAL_HOST%



:: =======================================
:: 8. 初始化目录
:: =======================================

echo.
echo =======================================
echo 初始化升级目录
echo =======================================

set "BACKUP_DIR=%UPGRADE_DIR%\backup"
set "DOWNLOAD_DIR=%UPGRADE_DIR%\download"

if not exist "%BACKUP_DIR%\plugins\shadow" (
    mkdir "%BACKUP_DIR%\plugins\shadow" >nul 2>&1
)

if not exist "%DOWNLOAD_DIR%" (
    mkdir "%DOWNLOAD_DIR%" >nul 2>&1
)

echo [INFO] 初始化完成



:: =======================================
:: 9. 检测系统架构
:: =======================================

echo.
echo =======================================
echo 检测系统架构
echo =======================================

set "TARGET_ARCH=amd64"

if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
    set "TARGET_ARCH=arm64"
)

echo [INFO] 当前系统架构:
echo(%TARGET_ARCH%



:: =======================================
:: 10. 构造下载地址
:: =======================================

set "URL=https://%FINAL_HOST%/api/console/files/download?file_name=agent^&os=windows^&arch=%TARGET_ARCH%^&version=%VERSION%^&type=package^&agent=true"

set "FILE_NAME=agent_windows_%TARGET_ARCH%_%VERSION%.tar"



:: =======================================
:: 11. 备份当前文件
:: =======================================

echo.
echo =======================================
echo 备份当前文件
echo =======================================

if exist "%WORK_DIR%\kernel.exe" (
    copy /y "%WORK_DIR%\kernel.exe" "%BACKUP_DIR%\" >nul
)

if exist "%WORK_DIR%\kernel.toml" (
    copy /y "%WORK_DIR%\kernel.toml" "%BACKUP_DIR%\" >nul
)

if exist "%WORK_DIR%\state.toml" (
    copy /y "%WORK_DIR%\state.toml" "%BACKUP_DIR%\" >nul
)

if exist "%WORK_DIR%\plugins\shadow\shadow.exe" (
    copy /y "%WORK_DIR%\plugins\shadow\shadow.exe" "%BACKUP_DIR%\plugins\shadow\" >nul
)

echo [INFO] 文件备份完成



:: =======================================
:: 12. tar 工具配置
:: =======================================

set "INSTALLER=%DOWNLOAD_DIR%\windows_tar_tool.exe"
set "GNU_BIN_PATH=C:\Program Files (x86)\GnuWin32\bin"
set "TAR_EXE=%GNU_BIN_PATH%\tar.exe"
set "TARGET_TAR=%DOWNLOAD_DIR%\%FILE_NAME%"

set "TAR_TOOL_URL=https://%FINAL_HOST%/api/console/files/download?file_name=windows+tar+tool^&os=windows^&arch=amd64^&version=v1.0.0^&type=package^&agent=false"



:: =======================================
:: 13. 下载 tar 工具
:: =======================================

echo.
echo =======================================
echo 下载 tar 解压工具
echo =======================================

powershell -Command ^
"[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; ^
[Net.ServicePointManager]::ServerCertificateValidationCallback={$true}; ^
$client=New-Object Net.WebClient; ^
try { ^
    $client.DownloadFile(\"%TAR_TOOL_URL%\", \"%INSTALLER%\") ^
} catch { ^
    exit 1 ^
}"

if not exist "%INSTALLER%" (
    echo [ERROR] tar 工具下载失败
    exit /b 1
)

echo [INFO] tar 工具下载成功



:: =======================================
:: 14. 安装 tar 工具
:: =======================================

echo.
echo =======================================
echo 安装 tar 解压工具
echo =======================================

start /wait "" "%INSTALLER%" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART >nul 2>&1

if not exist "%TAR_EXE%" (
    echo [ERROR] 未找到 tar.exe
    exit /b 1
)

echo [INFO] tar 工具安装完成



:: =======================================
:: 15. 下载升级包
:: =======================================

echo.
echo =======================================
echo 下载升级包
echo =======================================

echo [INFO] 下载地址:
echo(%URL%

powershell -Command ^
"[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; ^
[Net.ServicePointManager]::ServerCertificateValidationCallback={$true}; ^
$client=New-Object Net.WebClient; ^
try { ^
    $client.DownloadFile(\"%URL%\", \"%TARGET_TAR%\") ^
} catch { ^
    exit 1 ^
}" >nul 2>&1

if not exist "%TARGET_TAR%" (
    echo [ERROR] 升级包下载失败
    exit /b 1
)

for %%A in ("%TARGET_TAR%") do (
    if %%~zA==0 (
        echo [ERROR] 升级包大小为 0
        del /q /f "%TARGET_TAR%" >nul 2>&1
        exit /b 1
    )
)

echo [INFO] 升级包下载完成



:: =======================================
:: 16. 解压升级包
:: =======================================

echo.
echo =======================================
echo 解压升级包
echo =======================================

set "TEMP_PATH=temp_%random%"
set "TEMP_EXTRACT=%DOWNLOAD_DIR%\%TEMP_PATH%"

if not exist "%TEMP_EXTRACT%" (
    mkdir "%TEMP_EXTRACT%" >nul 2>&1
)

cd /d "%DOWNLOAD_DIR%"

"%TAR_EXE%" --force-local -xf "%FILE_NAME%" -C "%TEMP_PATH%" >nul 2>&1

if %errorlevel% neq 0 (
    echo [ERROR] 升级包解压失败
    exit /b 1
)

echo [INFO] 升级包解压完成



:: =======================================
:: 17. 禁止服务自动恢复
:: =======================================

echo.
echo =======================================
echo 禁止服务自动恢复
echo =======================================

sc failure kernel reset= 0 actions= "" >nul 2>&1
sc config kernel start= demand >nul 2>&1

echo [INFO] 已关闭自动恢复策略
echo [INFO] 已关闭自动启动



:: =======================================
:: 18. 停止 shadow.exe
:: =======================================

echo.
echo =======================================
echo 停止 shadow.exe
echo =======================================

taskkill /F /IM shadow.exe /T >nul 2>&1

:wait_shadow_exit

tasklist | find /i "shadow.exe" >nul

if %errorlevel% equ 0 (
    echo [INFO] 等待 shadow.exe 退出...
    timeout /t 2 /nobreak >nul
    goto wait_shadow_exit
)

echo [INFO] shadow.exe 已退出



:: =======================================
:: 19. 停止 kernel.exe
:: =======================================

echo.
echo =======================================
echo 停止 kernel.exe
echo =======================================

taskkill /F /IM kernel.exe /T >nul 2>&1

:wait_kernel_exit

tasklist | find /i "kernel.exe" >nul

if %errorlevel% equ 0 (
    echo [INFO] 等待 kernel.exe 退出...
    timeout /t 2 /nobreak >nul
    goto wait_kernel_exit
)

echo [INFO] kernel.exe 已退出



:: =======================================
:: 20. 替换 kernel.exe
:: =======================================

echo.
echo =======================================
echo 替换 kernel.exe
echo =======================================

if not exist "%TEMP_EXTRACT%\kernel.exe" (
    echo [ERROR] 升级包中不存在 kernel.exe
    exit /b 1
)

copy /y "%TEMP_EXTRACT%\kernel.exe" "%WORK_DIR%\kernel.exe" >nul

echo [INFO] kernel.exe 替换完成



:: =======================================
:: 21. 替换 shadow.exe
:: =======================================

echo.
echo =======================================
echo 替换 shadow.exe
echo =======================================

if not exist "%TEMP_EXTRACT%\plugins\shadow\shadow.exe" (
    echo [ERROR] 升级包中不存在 shadow.exe
    exit /b 1
)

if not exist "%WORK_DIR%\plugins\shadow" (
    mkdir "%WORK_DIR%\plugins\shadow" >nul 2>&1
)

copy /y "%TEMP_EXTRACT%\plugins\shadow\shadow.exe" "%WORK_DIR%\plugins\shadow\shadow.exe" >nul

(
    echo monitor:
    echo     interval: 60
    echo kernel:
    echo     wait_time: 300
    echo     interval: 5
) > "%WORK_DIR%\plugins\shadow\config.yaml"

echo [INFO] shadow.exe 替换完成



:: =======================================
:: 22. 恢复 Windows 服务配置
:: =======================================

echo.
echo =======================================
echo 恢复 Windows 服务配置
echo =======================================

sc config kernel start= auto >nul 2>&1

sc failure kernel reset= 86400 actions= restart/60000/restart/60000/restart/60000 >nul 2>&1

echo [INFO] 已恢复自动启动
echo [INFO] 已恢复失败自动恢复策略



:: =======================================
:: 23. 启动 kernel 服务
:: =======================================

echo.
echo =======================================
echo 启动 kernel 服务
echo =======================================

net start kernel >nul 2>&1

if %errorlevel% neq 0 (
    echo [ERROR] kernel 服务启动失败
    exit /b 1
)

echo [INFO] kernel 服务启动成功

timeout /t 5 /nobreak >nul



:: =======================================
:: 24. 查看服务状态
:: =======================================

echo.
echo =======================================
echo 查看服务状态
echo =======================================

sc query kernel | findstr "STATE"



:: =======================================
:: 25. 验证版本输出
:: =======================================

echo.
echo =======================================
echo 验证版本输出
echo =======================================

if exist "%WORK_DIR%\kernel.exe" (
    echo.
    echo [kernel.exe -version]
    "%WORK_DIR%\kernel.exe" -version
)

if exist "%WORK_DIR%\plugins\shadow\shadow.exe" (
    echo.
    echo [shadow.exe --version]
    "%WORK_DIR%\plugins\shadow\shadow.exe" --version
)



:: =======================================
:: 26. 清理临时文件
:: =======================================

echo.
echo =======================================
echo 清理临时文件
echo =======================================

if exist "%TEMP_EXTRACT%" (
    rmdir /s /q "%TEMP_EXTRACT%" >nul 2>&1
)

echo [INFO] 临时文件清理完成



:: =======================================
:: 27. 升级结束
:: =======================================

echo.
echo =======================================
echo 升级完成
echo =======================================

echo [INFO] 当前版本:
echo(%VERSION%

echo [INFO] kernel 服务运行正常
echo.

endlocal