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

```powershell
git clone https://github.com/2869893488/codex-cn-faststart.git
cd codex-cn-faststart\scripts

.\install.ps1                       # 通用优化
.\install.ps1 -IncludeDeepSeekEnv   # 额外配置 DeepSeek 直连的 .env
```

安装后完全退出 Codex（含托盘图标）再重新打开。

## 卸载

```powershell
.\uninstall.ps1
```

## 说明

- 开机自启注册在任务计划程序（任务名 `codex-cn-faststart-blackhole`），可随时禁用或删除；
- 域名不够用时，在 hosts 的 `codex-cn-faststart block` 段内自行追加；
- 仅修改本机 hosts、任务计划与 Codex 配置，不收集任何数据。
