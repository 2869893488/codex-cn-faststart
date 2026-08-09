# codex-cn-faststart 安装脚本
# 作用：让 OpenAI Codex 桌面版（Microsoft Store 打包应用）在国内不开 VPN 也能快速启动。
# 原理详见 README.md。脚本可重复执行（幂等）。
#
# 用法（PowerShell）：
#   .\install.ps1                      # 只安装通用快速启动组件
#   .\install.ps1 -IncludeDeepSeekEnv  # 额外写入 ~/.codex/.env 快速失败代理
#                                      # （DeepSeek 直连用户才需要）
param(
    [switch]$IncludeDeepSeekEnv
)
$ErrorActionPreference = 'Stop'

# ---------- 自动提权（改 hosts、加回环豁免需要管理员） ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($IncludeDeepSeekEnv) { $argList += ' -IncludeDeepSeekEnv' }
    Start-Process powershell -Verb RunAs -ArgumentList $argList -Wait
    exit $LASTEXITCODE
}

$root       = Split-Path $PSScriptRoot -Parent
$installDir = Join-Path $env:USERPROFILE '.codex\faststart'
New-Item -ItemType Directory -Path $installDir -Force | Out-Null

# ---------- 第 1 步：编译并启动回环黑洞服务 ----------
$exe = Join-Path $installDir 'loopback-blackhole.exe'
$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "未找到 C# 编译器：$csc" }
& $csc /nologo /optimize "/out:$exe" (Join-Path $root 'src\blackhole.cs')
if (-not (Test-Path $exe)) { throw '黑洞服务编译失败' }
if (-not (Get-Process -Name 'loopback-blackhole' -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $exe -WindowStyle Hidden
    Write-Host '[1/5] 黑洞服务已编译并启动'
} else {
    Write-Host '[1/5] 黑洞服务已在运行，跳过'
}

# ---------- 第 2 步：开机自启（任务计划，登录时隐藏运行） ----------
# 用任务计划程序而非启动文件夹：在"任务计划程序"里可见、可禁用、可删除，更透明温和。
# blackhole.exe 是控制台程序，直接 Run 会闪现黑色终端窗口；这里先由
# start-blackhole-hidden.ps1 用 CreateNoWindow 启动（不创建任何窗口），
# start-blackhole.vbs 只负责静默调用该 ps1（wscript 本身不弹窗）。
$ps1 = Join-Path $installDir 'start-blackhole-hidden.ps1'
@"
# Start loopback-blackhole.exe without creating any console window.
if (-not (Test-Path '$exe')) { exit 1 }
if (Get-Process -Name 'loopback-blackhole' -ErrorAction SilentlyContinue) { exit 0 }
`$psi = New-Object System.Diagnostics.ProcessStartInfo
`$psi.FileName = '$exe'
`$psi.UseShellExecute = `$false
`$psi.CreateNoWindow = `$true
`$psi.WindowStyle = 'Hidden'
[System.Diagnostics.Process]::Start(`$psi) | Out-Null
"@ | Set-Content -LiteralPath $ps1 -Encoding ASCII
$vbs = Join-Path $installDir 'start-blackhole.vbs'
@"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$ps1""", 0, False
"@ | Set-Content -LiteralPath $vbs -Encoding ASCII
$taskName = 'codex-cn-faststart-blackhole'
schtasks /create /tn $taskName /tr "wscript.exe `"$vbs`"" /sc onlogon /rl LIMITED /f | Out-Null
# 清理旧版本可能残留在启动文件夹里的 vbs
$legacyVbs = Join-Path ([Environment]::GetFolderPath('Startup')) 'loopback-blackhole.vbs'
if (Test-Path $legacyVbs) { Remove-Item $legacyVbs -Force; Write-Host '      已清理旧版启动文件夹项' }
Write-Host '[2/5] 开机自启已配置（任务计划：' + $taskName + '）'

# ---------- 第 3 步：hosts 快速失败屏蔽段 ----------
$hosts  = 'C:\Windows\System32\drivers\etc\hosts'
$marker = '# === codex-cn-faststart block ==='
if ((Get-Content -LiteralPath $hosts -Raw) -notmatch [regex]::Escape($marker)) {
    $domains = @(
        'chatgpt.com','chat.openai.com','openai.com','api.openai.com','auth.openai.com',
        'cdn.openai.com','ab.chatgpt.com','oaiusercontent.com','files.oaiusercontent.net',
        'oaistatic.com','persistent.oaistatic.com','cdn.oaistatic.com',
        'fonts.googleapis.com','fonts.gstatic.com','www.google-analytics.com',
        'ssl.google-analytics.com','update.googleapis.com','android.clients.google.com',
        'clients1.google.com','clients2.google.com','clients3.google.com',
        'clients4.google.com','clients5.google.com','www.googleapis.com',
        'cloud.googleapis.com','optimizationguide-pa.googleapis.com',
        'componentupdater.googleapis.com','safebrowsing.googleapis.com',
        'oauthaccountmanager.googleapis.com','accounts.google.com','www.google.com',
        'ssl.gstatic.com','www.gstatic.com','beacons.gcp.gvt2.com','beacons2.gvt2.com',
        'beacons3.gvt2.com','redirector.gvt1.com','connect.facebook.net','www.facebook.com',
        'mtalk.google.com'
    )
    $block = "`r`n$marker`r`n" + (($domains | ForEach-Object { "127.0.0.1 $_" }) -join "`r`n") + "`r`n# === end codex-cn-faststart block ===`r`n"
    Add-Content -LiteralPath $hosts -Value $block -Encoding ASCII
    ipconfig /flushdns | Out-Null
    Write-Host '[3/5] hosts 屏蔽段已写入并刷新 DNS'
} else {
    Write-Host '[3/5] hosts 屏蔽段已存在，跳过'
}

# ---------- 第 4 步：MSIX 回环豁免 ----------
# Store 打包应用默认禁止连接 localhost，不加豁免时发往 127.0.0.1 的 SYN 会被静默丢弃。
checknetisolation.exe loopbackexempt -a -n='OpenAI.Codex_2p2nqsd0c76g0' | Out-Null
Write-Host '[4/5] 已为 Codex 添加回环豁免'

# ---------- 第 5 步（可选）：.env 快速失败代理 ----------
if ($IncludeDeepSeekEnv) {
    $envFile   = Join-Path $env:USERPROFILE '.codex\.env'
    $envMarker = 'codex-cn-faststart'
    $needWrite = $true
    if (Test-Path $envFile) {
        if ((Get-Content $envFile -Raw) -match [regex]::Escape($envMarker)) {
            $needWrite = $false
        } else {
            $bak = "$envFile.backup-faststart-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $envFile $bak
            Write-Host "      原 .env 已备份到 $bak"
        }
    }
    if ($needWrite) {
        $envContent = @(
            '# codex-cn-faststart：OpenAI 请求走本地黑洞秒级失败，DeepSeek 走 NO_PROXY 直连',
            'HTTP_PROXY="http://127.0.0.1:443"',
            'HTTPS_PROXY="http://127.0.0.1:443"',
            'NO_PROXY="api.deepseek.com,deepseek.com,127.0.0.1,localhost"'
        )
        Set-Content -LiteralPath $envFile -Value $envContent -Encoding ASCII
        Write-Host '[5/5] .env 快速失败代理已写入'
    } else {
        Write-Host '[5/5] .env 已包含快速失败配置，跳过'
    }
} else {
    Write-Host '[5/5] 跳过 .env 配置（如需 DeepSeek 直连请加 -IncludeDeepSeekEnv 重跑）'
}

Write-Host ''
Write-Host '安装完成。请完全退出 Codex 桌面版（含托盘图标）后重新打开验证启动速度。'
Write-Host '卸载请运行 scripts\uninstall.ps1。'


