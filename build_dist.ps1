# Build a standalone Windows distribution of "Lincheng: Dawn & Dusk"
# Usage (from project root): powershell -ExecutionPolicy Bypass -File build_dist.ps1
# Or: right-click -> Run with PowerShell

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectRoot

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " Lincheng: Dawn & Dusk -- Windows Distribution" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# ---- Clean previous dist ----
if (Test-Path "dist") {
    Write-Host "Cleaning previous dist..."
    Remove-Item -Recurse -Force "dist"
}

# ---- Create directory structure ----
Write-Host "Creating dist\ structure..."
New-Item -ItemType Directory -Force -Path "dist\native" | Out-Null

# ---- Step 1: Build .love archive ----
Write-Host ""
Write-Host "[1/3] Creating .love archive..." -ForegroundColor Yellow
$loveFile = Join-Path $ProjectRoot "blue-hours.love"
if (Test-Path $loveFile) { Remove-Item $loveFile }

$staging = Join-Path $ProjectRoot "___love_staging___"
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
New-Item -ItemType Directory -Force -Path $staging | Out-Null

# Copy top-level source files
$topFiles = @('main.lua', 'conf.lua')
foreach ($f in $topFiles) {
    Copy-Item $f $staging
}

# Copy source folders (Lua code lives under src-lua/)
$folders = @('src-lua')
foreach ($f in $folders) {
    Copy-Item -Recurse $f (Join-Path $staging $f)
}

# Copy native/ folder (excluding the venv at native/mpenv which is large and
# recreated by setup.bat on the target machine)
Copy-Item -Recurse 'native' (Join-Path $staging 'native') -Force
if (Test-Path (Join-Path $staging 'native\mpenv')) {
    Remove-Item -Recurse -Force (Join-Path $staging 'native\mpenv')
}

# Create zip archive (= .love file)
Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $loveFile -Force
Remove-Item -Recurse -Force $staging

if (-not (Test-Path $loveFile)) {
    Write-Error "Failed to create blue-hours.love"
    exit 1
}
$loveSize = [math]::Round((Get-Item $loveFile).Length / 1KB, 1)
Write-Host "  OK -- blue-hours.love ($loveSize KB)" -ForegroundColor Green

# ---- Step 2: Fuse with love.exe -> Lincheng.exe ----
Write-Host ""
Write-Host "[2/3] Fusing with LOVE2D runtime -> Lincheng.exe..." -ForegroundColor Yellow
$loveExe = Join-Path $ProjectRoot "LOVE\love.exe"
$outputExe = Join-Path $ProjectRoot "dist\Lincheng.exe"
if (-not (Test-Path $loveExe)) {
    Write-Error "LOVE\love.exe not found"
    exit 1
}

# Fuse: concatenate love.exe + .love (standard LOVE2D fusion method)
$loveBytes = [System.IO.File]::ReadAllBytes($loveExe)
$gameBytes = [System.IO.File]::ReadAllBytes($loveFile)
[System.IO.File]::WriteAllBytes($outputExe, $loveBytes + $gameBytes)
Remove-Item $loveFile

$exeSize = [math]::Round((Get-Item $outputExe).Length / 1MB, 2)
Write-Host "  OK -- Lincheng.exe ($exeSize MB)" -ForegroundColor Green

# ---- Step 3: Copy runtime DLLs + native/ scripts ----
Write-Host ""
Write-Host "[3/3] Copying runtime DLLs and native/ scripts..." -ForegroundColor Yellow
$dlls = @('SDL2.dll', 'OpenAL32.dll', 'love.dll', 'lua51.dll',
         'mpg123.dll', 'msvcp120.dll', 'msvcr120.dll')
foreach ($d in $dlls) {
    $src = Join-Path (Join-Path $ProjectRoot 'LOVE') $d
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $ProjectRoot "dist\$d")
    } else {
        Write-Warning "Missing LOVE/$d"
    }
}
# Icons
@('love.ico', 'game.ico') | ForEach-Object {
    $src = Join-Path (Join-Path $ProjectRoot 'LOVE') $_
    if (Test-Path $src) { Copy-Item $src (Join-Path $ProjectRoot "dist\$_") }
}

# native/ scripts (the .exe looks for these on the filesystem to launch Python)
Copy-Item 'native\gesture_detector.py' 'dist\native\gesture_detector.py' -Force
Copy-Item 'native\gesture_thread.lua'  'dist\native\gesture_thread.lua'  -Force
Copy-Item 'native\setup.bat'           'dist\native\setup.bat'           -Force
Copy-Item 'native\setup.sh'            'dist\native\setup.sh'            -Force

# Top-level convenience launcher for dependency install
@'
@echo off
REM One-time dependency installer for Lincheng
REM Creates Python venv, installs packages, downloads model
cd /d "%~dp0native"
call setup.bat
'@ | Set-Content -Encoding ASCII 'dist\安装依赖.bat'

# Quick-start instructions (Chinese)
@'
Lincheng: Dawn & Dusk -- Windows 分发
===========================================

首次使用（必须运行一次）：
   双击 "安装依赖.bat"
   这会自动创建 Python 虚拟环境、安装 MediaPipe+OpenCV、下载手势模型。
   需要联网（下载约 100MB 的 Python 依赖包）。

之后：
   双击 Lincheng.exe 即可运行

快捷键：
   f     - 切换全屏
   d     - 切换调试面板
   space - 暂停/继续输入
   esc   - 退出
   鼠标左键 - 切换视觉状态（塔 / 流 / 贵阳文字）

手势识别（摄像头必须可用）：
   握拳    - 循环状态
   拇指点赞 - 跳到贵阳文字
   V字     - 进入 ASCII 模式（5秒）
'@ | Set-Content -Encoding UTF8 'dist\说明.txt'

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " Build complete.  Contents of dist\:" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Cyan
Get-ChildItem 'dist' | ForEach-Object {
    Write-Host ("   {0,-25} {1,8} KB" -f $_.Name, [math]::Round($_.Length/1KB,1))
}
Write-Host ""
Write-Host " dist\native\  contains:" -ForegroundColor Gray
Get-ChildItem 'dist\native' | ForEach-Object {
    Write-Host ("   {0,-25} {1,8} KB" -f $_.Name, [math]::Round($_.Length/1KB,1))
}
Write-Host ""
Write-Host " Next step: run dist\安装依赖.bat  once, then launch dist\Lincheng.exe" -ForegroundColor Yellow
