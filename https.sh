#!/usr/bin/env bash
# HTTPS Proxy Installation Script
# Author: https://1024.day

set -Eeuo pipefail
trap 'echo "[ERROR] Command failed at line $LINENO" >&2' ERR

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "Error: This script must be run as root!" 1>&2
    exit 1
fi

validate_domain() {
    local d="$1"
    [[ "$d" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]
}

Passwd=$(head -c 16 /dev/urandom | md5sum | head -c 12)

# Download Caddy binary (prebuilt bundle from repo)
curl -fSL https://github.com/yeahwu/v2ray-wss/releases/download/v-monthly/caddy-v-monthly.tar.gz | tar -xz -C /usr/local/

chmod +x /usr/local/caddy

echo "==== 输入已经 DNS 解析好的域名 ===="
read -r domain
if [[ -z "$domain" ]] || ! validate_domain "$domain"; then
    echo "域名格式无效" >&2; exit 1
fi

isPort=$(netstat -ntlp 2>/dev/null | grep -E ':80 |:443 ' || true)
if [[ -n "$isPort" ]]; then
    echo " ================================================== "
    echo " 80或443端口被占用，请先释放端口再运行此脚本"
    echo
    echo " 端口占用信息如下："
    echo "$isPort"
    echo " ================================================== "
    exit 1
fi

mkdir -p /etc/caddy

cat >/etc/caddy/https.caddyfile<<EOF
:443, $domain
route {
    forward_proxy {
        basic_auth 1024 $Passwd
        hide_ip
        hide_via
    }
    file_server
}
EOF

cat >/etc/systemd/system/caddy.service<<EOF
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
User=root
ExecStart=/usr/local/caddy run --environ --config /etc/caddy/https.caddyfile
ExecReload=/usr/local/caddy reload --config /etc/caddy/https.caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable caddy.service
systemctl restart caddy.service
systemctl status --no-pager caddy.service || true

cat >/etc/caddy/https.txt<<EOF
=========== 配置参数 =============
代理模式：Https正向代理
地址：${domain}
端口：443
用户：1024
密码：${Passwd}
=================================
http=$domain:443, username=1024, password=$Passwd, over-tls=true, tls-verification=true, tls-host=$domain, udp-relay=false, tls13=true, tag=https
EOF

echo
echo "安装已经完成"
echo
echo "=========== Https 配置参数 ============"
echo
echo "地址：${domain}"
echo "端口：443"
echo "密码：${Passwd}"
echo "用户：1024"
echo
echo "======================================"
echo "http=$domain:443, username=1024, password=$Passwd, over-tls=true, tls-verification=true, tls-host=$domain, udp-relay=false, tls13=true, tag=https"
echo
