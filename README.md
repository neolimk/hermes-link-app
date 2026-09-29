# Hermes 手机端远程访问 —— 自托管部署套装

> 用 `frp` 反向隧道 + 云端 `nginx`，把电脑端的 **Hermes Desktop** 通过域名暴露给手机上的 **Hermes Mobile**（开源 Android 客户端）访问。手机可登录 dashboard、聊天、管理会话/模型/定时任务等。

本套装是**通用部署模板**，所有私密信息已参数化（`YOUR_*` 占位符），请替换成你自己的值。

---

## 1. 架构总览

```
手机 Hermes Mobile
   │  https://your-domain
   ▼
云端 nginx (443, TLS)          ← 服务器 123.x.x.x
   │  proxy_pass 127.0.0.1:18787
   ▼
frps (服务器, proxyBindAddr=127.0.0.1)
   ▲  反向隧道 (frpc 外连, 端口 7000)
   │
frpc (Windows 电脑)  local 127.0.0.1:9119
   ▼
hermes dashboard (电脑端, 端口 9119)
   └── 连到桌面后端 hermes serve
```

- **电脑端**跑 `hermes dashboard`（端口 9119），它承载登录页 / API / WebSocket。
- **隧道**由 frpc 外连云端 frps，把云端 18787 转发到本机 9119。
- **nginx** 把域名反代到 `127.0.0.1:18787`，并加 HTTPS。

---

## 2. 电脑端：启用 gateway API + dashboard

Hermes 桌面版跑的是 `hermes serve`（随机端口）。**手机客户端连的是 dashboard（9119）**，不是那个随机端口。

```powershell
# 在 hermes 配置目录 (Windows: C:\Users\<你>\AppData\Local\hermes)
hermes config set platforms.api_server.enabled true
# 在 .env 里设置强 API 密钥(>=16字符)：API_SERVER_KEY=YOUR_STRONG_KEY

# 设置 dashboard 公网域名(否则反向代理会被 Host 头校验拒绝)
hermes config set dashboard.public_url https://YOUR_DOMAIN
```

启动 dashboard 时会提示选择认证方式，选 **1) 用户名+密码**，设置登录账号密码 —— 这就是手机端要用的账号。

---

## 3. 云端服务器：装 frps + nginx

把 `scripts/setup-cloud.sh` 放到服务器执行（或用 `config/nginx-hermes.conf` 手动配 nginx）。

```bash
# 服务器上
bash setup-cloud.sh          # 下载 frp、装 frps systemd 服务、配好 frps.toml
```

> 注意：华为云/阿里云等**安全组**和服务器**本机 ufw** 都要放行 `7000/tcp`，缺一不可。

---

## 4. 电脑端：frpc + 常驻计划任务

1. 把 `frpc.exe`（frp windows_amd64 版）和 `config/frpc.toml.example`（改名 `frpc.toml` 并填好服务器/令牌）放到 `C:\frp\`。
2. **用管理员 PowerShell** 运行 `scripts/install-all.ps1`，它会注册两个计划任务：
   - `HermesFrpc`（系统开机自启，崩溃自动重启）—— 维持隧道
   - `HermesDashboard`（登录自启，崩溃自动重启）—— 维持 9119 dashboard

> **为什么用计划任务而不是服务？** frpc/dashboard 是普通控制台程序，`sc create` 直接当服务会因"未及时响应 SCM"失败；计划任务 + `RestartCount` 才是 Windows 上可靠的常驻方案。

---

## 5. 手机端：Hermes Mobile

- 下载 APK：`https://github.com/Hy4ri/hermes-mobile/releases/latest`（或 F-Droid 搜 `com.m57.hermescontrol`）。本套装 `apk/` 目录已附官方 APK。
- 打开 app → 添加服务器连接：
  - 地址：`https://YOUR_DOMAIN`
  - 用户名/密码：第 2 步设置的账号
- 连上后即可在手机控制电脑端的 Hermes。

---

## 6. 验证

```bash
curl -sk https://YOUR_DOMAIN/          # 应 302 -> /login -> 200 登录页
curl -sk https://YOUR_DOMAIN/api/auth/status   # 无会话时 401(正常)
```

| 症状 | 原因 |
|------|------|
| 502 Bad Gateway | nginx 连不到 18787：frpc 没跑 / 隧道断 |
| 404 根路径 | 隧道指到了 8642(api_server) 而非 9119(dashboard) |
| `Invalid Host header` | 没设 `dashboard.public_url` |
| 直连 `/` 空/400 | Host 校验拦截 |

---

## 7. 参考文件

- `config/frpc.toml.example` — frpc 客户端配置模板
- `config/nginx-hermes.conf` — nginx vhost 模板（SSE/WebSocket 反代）
- `scripts/setup-cloud.sh` — 云端 frps 一键脚本
- `scripts/install-all.ps1` — 电脑端计划任务一键注册（管理员运行）
- `skill/hermes-remote-access.md` — 完整技能文档（含全部排错经验）