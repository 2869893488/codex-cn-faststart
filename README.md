# codex-cn-faststart

让 Codex 桌面版（Microsoft Store 版）在国内免 VPN 快速启动。工具通过 hosts、本地回环黑洞服务和 MSIX 回环豁免，让不可达请求快速失败。

## 安装

```powershell
git clone https://github.com/2869893488/codex-cn-faststart.git
cd codex-cn-faststart\scripts

.\install.ps1                        # 默认：按需启动，不注册登录自启
.\install.ps1 -Lightweight           # 按需启动，并生成桌面 ChatGPT 快捷方式
.\install.ps1 -EnableAutoStart       # 明确启用登录自启
.\install.ps1 -IncludeDeepSeekEnv    # 可选：配置 DeepSeek 直连的 .env
```

默认安装不会注册开机或登录自启任务，因此不会因本工具在开机时弹出终端窗口。按需模式会生成桌面 `ChatGPT.lnk`，双击时静默启动黑洞服务后打开 Codex。只有显式传入 `-EnableAutoStart` 才会创建任务 `codex-cn-faststart-blackhole`。

安装后请完全退出 Codex（包括托盘进程）再重新打开。

## 卸载

```powershell
.\uninstall.ps1
```

卸载会移除本工具写入的 hosts 屏蔽段、登录任务、启动器、桌面快捷方式、黑洞进程和回环豁免；默认不会修改 `~/.codex/.env`。

## 说明

- 工具只修改本机 hosts、任务计划和 Codex 配置，不收集数据。
- 如需还原安装时备份的 `.env`，运行 `.\uninstall.ps1 -RestoreEnvBackup`。
- 域名不够用时，可在 hosts 的 `codex-cn-faststart block` 段内自行追加。
