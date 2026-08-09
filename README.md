# codex-cn-faststart

让 Codex 桌面版（Microsoft Store 版）在国内免 VPN 快速启动。实测冷启动约 20 秒 → 约 3 秒。

## 原理

Codex 启动时会请求一批国内不可达的境外域名（OpenAI、Google、Facebook 等），连接挂起等待超时，拖慢启动。本工具让这些请求毫秒级失败：

- hosts 屏蔽段：相关域名指向 `127.0.0.1`；
- 本地黑洞服务：监听 `127.0.0.1:443`，接受连接后立即关闭，保证毫秒级错误返回；
- 回环豁免：Store 打包应用默认不能连 localhost，用 `checknetisolation` 添加豁免；
- （可选）`~/.codex/.env` 快速失败代理，`NO_PROXY` 放行 DeepSeek 等国内直连模型。

开 VPN 使用官方订阅不受影响（系统代理模式下 DNS 由代理端解析）。

## 安装

两种模式二选一：

```powershell
git clone https://github.com/2869893488/codex-cn-faststart.git
cd codex-cn-faststart\scripts

.\install.ps1                        # 默认：登录时自动运行黑洞服务，开机即用
.\install.ps1 -Lightweight           # 轻量：开机零自启，用桌面 ChatGPT 快捷方式按需启动
.\install.ps1 -IncludeDeepSeekEnv    # 额外配置 DeepSeek 直连的 .env（可与上面组合）
```

- **默认模式**：注册登录自启任务（任务计划，隐藏运行），登录后黑洞服务自动在线，直接打开 Codex 即可，启动最快；
- **轻量模式**：不注册任何自启，开机零进程、零常驻；安装时生成桌面 **ChatGPT** 快捷方式（原版图标），双击后先毫秒级拉起黑洞服务再启动 Codex，体验一致、更干净。若此前装过默认模式，切到轻量会自动删除自启任务。

安装后完全退出 Codex（含托盘图标）再重新打开。

## 卸载

```powershell
.\uninstall.ps1
```

两种模式的自启任务、桌面 ChatGPT 快捷方式、启动器脚本都会被一并清理。

## 说明

- 默认模式开机自启注册在任务计划程序（任务名 `codex-cn-faststart-blackhole`），可随时禁用或删除；
- 轻量模式依赖桌面 ChatGPT 快捷方式（对应 `~/.codex/faststart/launch-codex.vbs`）；从开始菜单直接打开 Codex 也能用，只是黑洞未在线时启动会比最快慢约 2~3 秒；
- 域名不够用时，在 hosts 的 `codex-cn-faststart block` 段内自行追加；
- 仅修改本机 hosts、任务计划与 Codex 配置，不收集任何数据。
