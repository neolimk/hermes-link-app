# ===== Hermes 远程访问：电脑端计划任务一键安装 =====
# 作用：注册 frpc(隧道) + HermesDashboard 两个常驻计划任务(开机/登录自启,崩溃自动重启)
# 用法：管理员 PowerShell 运行  powershell -ExecutionPolicy Bypass -File install-all.ps1
# 前提：C:\frp\frpc.exe 和 C:\frp\frpc.toml 已就位；hermes 安装在默认路径

$hermes = 'C:\Users\Administrator\AppData\Local\hermes\hermes-agent\venv\Scripts\hermes.exe'
$frpc   = 'C:\frp\frpc.exe'

# --- frpc: 系统开机任务(SYSTEM) ---
sc.exe delete HermesFrpc 2>$null | Out-Null
$a1 = New-ScheduledTaskAction -Execute $frpc -Argument '-c C:\frp\frpc.toml'
$t1 = New-ScheduledTaskTrigger -AtStartup
$s1 = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
$p1 = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName 'HermesFrpc' -Action $a1 -Trigger $t1 -Settings $s1 -Principal $p1 -Force | Out-Null
Start-ScheduledTask -TaskName 'HermesFrpc'

# --- dashboard: 登录任务(Administrator) ---
$a2 = New-ScheduledTaskAction -Execute $hermes -Argument 'dashboard --port 9119 --host 127.0.0.1 --skip-build --no-open'
$t2 = New-ScheduledTaskTrigger -AtLogOn -User 'Administrator'
$s2 = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
$p2 = New-ScheduledTaskPrincipal -UserId 'Administrator' -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'HermesDashboard' -Action $a2 -Trigger $t2 -Settings $s2 -Principal $p2 -Force | Out-Null
Start-ScheduledTask -TaskName 'HermesDashboard'

Start-Sleep -Seconds 8
Write-Output '=== TASKS ==='
Get-ScheduledTask | Where-Object { $_.TaskName -match 'Hermes' } | Select-Object TaskName,State | Format-Table -AutoSize
Write-Output '=== PORT 9119 ==='
if (Get-NetTCPConnection -LocalPort 9119 -State Listen -ErrorAction SilentlyContinue) { Write-Output '9119 LISTENING OK' } else { Write-Output '9119 DOWN' }