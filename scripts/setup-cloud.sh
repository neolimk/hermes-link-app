#!/usr/bin/env bash
# ===== Hermes 远程访问：云端 frps 一键安装 =====
# 用法：在服务器 root 下  bash setup-cloud.sh
# 需要：服务器能访问 github；已有 nginx + certbot(可选)
set -euo pipefail

FRP_VERSION="0.71.0"
FRP_SERVER_IP="${1:-YOUR_SERVER_IP}"          # 公网 IP(可选,仅显示用)
FRP_TOKEN="${FRP_TOKEN:-YOUR_SHARED_TOKEN}"   # 与电脑 frpc.toml 一致

echo "==> 安装 frps ${FRP_VERSION}"
cd /opt
curl -sL --retry 4 -m 900 -o frp.tar.gz \
  "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"
tar xzf frp.tar.gz
mkdir -p /opt/frp
cp "frp_${FRP_VERSION}_linux_amd64/frps" /opt/frp/
chmod +x /opt/frp/frps
rm -rf "frp_${FRP_VERSION}_linux_amd64" frp.tar.gz

echo "==> 写 frps.toml (代理端口只绑 127.0.0.1, 只有 nginx 能到)"
cat > /opt/frp/frps.toml <<EOF
bindPort = 7000
auth.method = "token"
auth.token = "${FRP_TOKEN}"
proxyBindAddr = "127.0.0.1"
EOF

echo "==> 注册 systemd 服务"
cat > /etc/systemd/system/frps.service <<'EOF'
[Unit]
Description=frp server (hermes tunnel)
After=network.target
[Service]
ExecStart=/opt/frp/frps -c /opt/frp/frps.toml
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable frps --now
systemctl is-active frps

echo "==> ufw 放行 7000(服务器本机防火墙)"
ufw allow 7000/tcp || true

echo "==> 完成. 记得在云厂商安全组也放行 7000/tcp"
echo "    nginx vhost 用 config/nginx-hermes.conf 模板(反代 127.0.0.1:18787)"