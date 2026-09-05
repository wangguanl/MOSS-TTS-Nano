<#
.SYNOPSIS
  一键启动 MOSS-TTS-Nano 文本转语音服务（后台运行 + 自动打开浏览器）
#>

# ============ 可配置项 ============
$CheckpointPath    = "E:\huggingface_cache\MOSS-TTS-Nano"
$AudioTokenizerPath = "E:\huggingface_cache\MOSS-Audio-Tokenizer-Nano"
$HostAddress       = "localhost"
$Port              = 18083
# =================================

$ErrorActionPreference = "Stop"

$ProjectDir = $PSScriptRoot
if (-not $ProjectDir) { $ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$PythonExe = Join-Path $ProjectDir ".venv\Scripts\python.exe"
$AppPy     = Join-Path $ProjectDir "app.py"
$Url       = "http://${HostAddress}:${Port}/"
$LogFile   = Join-Path $ProjectDir "app_server.log"
$ErrFile   = Join-Path $ProjectDir "app_server_err.log"

# 0. 环境检查
$missing = @()
if (-not (Test-Path $PythonExe)) { $missing += "虚拟环境 Python：$PythonExe" }
if (-not (Test-Path $AppPy))     { $missing += "应用入口：$AppPy" }
if (-not (Test-Path $CheckpointPath))    { $missing += "模型目录：$CheckpointPath" }
if (-not (Test-Path $AudioTokenizerPath)) { $missing += "音频分词器目录：$AudioTokenizerPath" }
if ($missing.Count -gt 0) {
    Write-Host "[错误] 以下路径不存在：" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Read-Host "按回车键退出"
    exit 1
}

# 1. 检查端口是否已被占用（避免重复启动）
$existing = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "[提示] 端口 $Port 已有服务在监听，直接打开浏览器。" -ForegroundColor Yellow
    Start-Process $Url
    exit 0
}

# 2. 启动服务（独立后台进程，关闭本窗口后仍会运行）
Write-Host "[1/3] 正在启动 MOSS-TTS-Nano 服务（$Url）..." -ForegroundColor Cyan
$proc = Start-Process -FilePath $PythonExe `
    -ArgumentList @(
        $AppPy,
        "--checkpoint-path", $CheckpointPath,
        "--audio-tokenizer-path", $AudioTokenizerPath,
        "--host", $HostAddress,
        "--port", "$Port"
    ) `
    -WorkingDirectory $ProjectDir `
    -RedirectStandardOutput $LogFile `
    -RedirectStandardError $ErrFile `
    -WindowStyle Hidden `
    -PassThru

# 3. 等待 HTTP 就绪
Write-Host "[2/3] 等待服务就绪（模型加载约需 30~60 秒）..." -ForegroundColor Cyan
$httpReady = $false
for ($i = 0; $i -lt 90; $i++) {
    Start-Sleep -Seconds 2
    if ($proc.HasExited) {
        Write-Host "[错误] 服务进程异常退出，最近日志如下：" -ForegroundColor Red
        if (Test-Path $ErrFile) { Get-Content $ErrFile -Tail 20 }
        Read-Host "按回车键退出"
        exit 1
    }
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
        if ($resp.StatusCode -eq 200) { $httpReady = $true; break }
    } catch { }
}
if (-not $httpReady) {
    Write-Host "[错误] 服务启动超时，请查看日志：$ErrFile" -ForegroundColor Red
    Read-Host "按回车键退出"
    exit 1
}

# 4. 等待模型预热完成
Write-Host "[3/3] 服务已就绪，等待模型预热完成..." -ForegroundColor Cyan
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 2
    try {
        $ws = Invoke-WebRequest -Uri "http://${HostAddress}:${Port}/api/warmup-status" -UseBasicParsing -TimeoutSec 2
        $json = $ws.Content | ConvertFrom-Json
        if ($json.ready) {
            Write-Host "      预热状态：$($json.status_text)" -ForegroundColor Green
            break
        }
    } catch { }
}

Write-Host ""
Write-Host "服务已启动：$Url" -ForegroundColor Green
Write-Host "日志文件：$LogFile" -ForegroundColor DarkGray
Start-Process $Url
