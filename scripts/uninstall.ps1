# codex-cn-faststart 卸载脚本
# 移除安装脚本所做的全部修改：hosts 屏蔽段、开机自启、黑洞服务、回环豁免。
# 默认不动 ~/.codex/.env；加 -RestoreEnvBackup 可用最近一次安装备份还原 .env。
param(
    [switch]$RestoreEnvBackup
)
$ErrorActionPreference = 'Stop'

# ---------- 自动提权 ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($RestoreEnvBackup) { $argList += ' -RestoreEnvBackup' }
    Start-Process powershell -Verb RunAs -ArgumentList $argList -Wait
    exit $LASTEXITCODE
}

# ---------- 1. 移除 hosts 屏蔽段 ----------
$hosts  = 'C:\Windows\System32\drivers\etc\hosts'
$marker = '# === codex-cn-faststart block ==='
$text = Get-Content -LiteralPath $hosts -Raw
if ($text -match [regex]::Escape($marker)) {
    $pattern = "(?ms)\r?\n$([regex]::Escape($marker)).*?# === end codex-cn-faststart block ===\r?\n"
    ($text -replace $pattern, "`r`n") | Set-Content -LiteralPath $hosts -Encoding ASCII
    ipconfig /flushdns | Out-Null
    Write-Host '[1/4] hosts 屏蔽段已移除并刷新 DNS'
} else {
    Write-Host '[1/4] hosts 中无屏蔽段，跳过'
}

# ---------- 2. 移除开机自启与启动器（默认模式任务计划 + 轻量模式启动器都清理） ----------
$taskName = 'codex-cn-faststart-blackhole'
schtasks /delete /tn $taskName /f 2>$null | Out-Null
$vbs = Join-Path (Join-Path $env:USERPROFILE '.codex\faststart') 'start-blackhole.vbs'
if (Test-Path $vbs) { Remove-Item $vbs -Force }
$launcherVbs = Join-Path (Join-Path $env:USERPROFILE '.codex\faststart') 'launch-codex.vbs'
if (Test-Path $launcherVbs) { Remove-Item $launcherVbs -Force }
$desktopLnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'ChatGPT.lnk'
if (Test-Path $desktopLnk) { Remove-Item $desktopLnk -Force }
$legacyVbs = Join-Path ([Environment]::GetFolderPath('Startup')) 'loopback-blackhole.vbs'
if (Test-Path $legacyVbs) { Remove-Item $legacyVbs -Force }
Write-Host '[2/4] 开机自启与启动器已移除'

# ---------- 3. 停止黑洞服务 ----------
$proc = Get-Process -Name 'loopback-blackhole' -ErrorAction SilentlyContinue
if ($proc) { $proc | Stop-Process -Force; Write-Host '[3/4] 黑洞服务已停止' }
else { Write-Host '[3/4] 黑洞服务未运行，跳过' }

# ---------- 4. 移除回环豁免 ----------
checknetisolation.exe loopbackexempt -d -n='OpenAI.Codex_2p2nqsd0c76g0' | Out-Null
Write-Host '[4/4] 回环豁免已移除'

# ---------- （可选）还原 .env ----------
if ($RestoreEnvBackup) {
    $envFile = Join-Path $env:USERPROFILE '.codex\.env'
    $latest = Get-ChildItem (Join-Path $env:USERPROFILE '.codex') -Filter '.env.backup-faststart-*' -Force -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) {
        Copy-Item $latest.FullName $envFile -Force
        Write-Host "已用备份还原 .env：$($latest.Name)"
    } else {
        Write-Host '未找到 .env 安装备份，无法还原'
    }
}

Write-Host ''
Write-Host '卸载完成。编译产物保留在 ~/.codex/faststart/，可手动删除。'


