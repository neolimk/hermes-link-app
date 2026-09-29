# Skill: Hermes 远程访问（手机 / 外网客户端）

> 把电脑端 Hermes Desktop 通过 frp + nginx 暴露给手机端 Hermes Mobile。
> 两层都要：① 一个手机能连的端点 = gateway API server(8642) 或 **dashboard(9119)**；② 一条从外网到这个端口的通路 = frp 隧道 + nginx + 防火墙。

## 关键结论（本次实战排错沉淀）

- **手机客户端连的是 dashboard(9119)，不是 8642(api_server)、也不是桌面 serve 的随机端口。** 隧道 localPort 必须指 9119。
- 桌面版跑 `hermes serve`(随机端口)，它不承载 dashboard。dashboard 要单独 `hermes dashboard --port 9119 --host 127.0.0.1 --skip-build --no-open` 常驻。
- dashboard 有 **Host 头校验**：必须设 `dashboard.public_url https://你的域名`，否则反代过来报 `Invalid Host header`(400)。
- dashboard 配了公网域名后**强制要求认证**，启动时选"用户名+密码"，设的账号就是手机登录凭据。
- `--insecure` 已废弃(2026-06 加固后不再绕过认证)。

## 诊断顺序（502 / 连不上时）
1. 本机 8642/9119 是否监听？ `netstat -ano | grep -E ':9119\b.*LISTENING'`
2. 云端 18787 是否监听？ `ss -tlnp | grep 18787`（frps 上，frpc 注册了代理才出现）
3. 云端本地 `curl http://127.0.0.1:18787/health` 通不通
4. 公网 `curl -sk https://域名/` → 应 302 到 /login 再 200

## 症状表
| 症状 | 原因 |
|------|------|
| 502 | nginx 连不到 18787：frpc 没跑 / 隧道断 |
| 404 根路径 | 隧道指向 8642(api_server) 而非 9119(dashboard) |
| Invalid Host header | 没设 dashboard.public_url |
| 连上但 WebSocket 断 | nginx 缺 WebSocket Upgrade 头 |
| 手机能连但云端 7000 超时 | 云安全组 或 服务器 ufw 没放行(两个都要) |

## Windows 常驻方案
- **frpc 不能直接当服务**(控制台程序,SERVICE_START 超时)。用计划任务:SYSTEM 开机任务 + RestartCount/RestartInterval 自动重启。
- dashboard 用 Administrator 登录任务同样方式。
- 计划任务脚本的 .ps1 输出**必须纯 ASCII**(Win PS5.1 无 BOM 按 GBK 读中文会乱码崩解析)。
- MSYS bash 里 `$_`/反斜杠会被展开,写 .ps1 用 `powershell -File C:/路径/x.ps1`(正斜杠)执行。

## frp 要点
- 配置键 camelCase：`proxyBindAddr`(frps 绑定代理端口到 127.0.0.1)、`bindPort`。
- frpc 加 `loginFailExit = false` 持续重试。
- frp 下载慢/被墙:在能访问 github 的一端下,scp 到另一端。
- 云端 sshd 别用 `pkill -f "下载URL"` 自匹配命令行会杀会话(exit 255)。

## 验证清单
- `dashboard.public_url` 已设; dashboard 9119 监听; frpc 隧道在; nginx 反代 18787 + WebSocket 头; 手机用账号登录。