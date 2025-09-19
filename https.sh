#!/usr/bin/env bash
# HTTPS Proxy Installation Script
# Author: https://1024.day

set -Eeuo pipefail
trap 'echo "[ERROR] Command failed at line $LINENO" >&2' ERR

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "Error: This script must be run as root!" 1>&2
    exit 1
fi

# ---------- UI helpers ----------
GREEN='\033[32m'; RED='\033[31m'; YELLOW='\033[33m'; CYAN='\033[36m'; BLUE='\033[34m'; BOLD='\033[1m'; RESET='\033[0m'
CHECK="${GREEN}✓${RESET}"; CROSS="${RED}✗${RESET}"; WARN="${YELLOW}!${RESET}"

banner() {
    clear
    echo -e "${CYAN}${BOLD}==============================================${RESET}"
    echo -e "${CYAN}${BOLD}    Caddy HTTPS 正向代理 一键安装${RESET}"
    echo -e "${CYAN}${BOLD}==============================================${RESET}"
}

step()    { echo -e "${BLUE}➤${RESET} $*"; }
ok()      { echo -e "  ${CHECK} $*"; }
warn()    { echo -e "  ${WARN} $*"; }
fail()    { echo -e "  ${CROSS} $*"; }

validate_domain() {
    local d="$1"
    [[ "$d" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]
}

get_server_ip() {
    local ip=""
    local sources_v4=(
        "http://www.cloudflare.com/cdn-cgi/trace"
        "https://api.ipify.org"
        "https://ipinfo.io/ip"
    )
    for src in "${sources_v4[@]}"; do
        if [[ "$src" == *cloudflare* ]]; then
            ip=$(curl -fsS4 --connect-timeout 10 --max-time 15 "$src" | awk -F'=' '/^ip=/{print $2}' | tr -d '\r\n' || true)
        else
            ip=$(curl -fsS4 --connect-timeout 10 --max-time 15 "$src" | tr -d '\r\n' || true)
        fi
        [[ -n "$ip" ]] && break || true
    done
    echo "$ip"
}

resolve_domain_ips() {
    local host="$1"
    getent hosts "$host" 2>/dev/null | awk '{print $1}' | sort -u
}

Passwd=$(head -c 16 /dev/urandom | md5sum | head -c 12)

banner
step "准备安装..."

echo -e "\n${BOLD}请输入已完成 DNS 解析的域名：${RESET}"
read -r -p "> " domain
if [[ -z "$domain" ]] || ! validate_domain "$domain"; then
    fail "域名格式无效"
    exit 1
fi

SERVER_IP=$(get_server_ip)
RESOLVED_IPS=$(resolve_domain_ips "$domain" | tr '\n' ' ')

if [[ -z "$SERVER_IP" ]]; then
    warn "无法自动获取服务器IP，将跳过解析一致性检查"
else
    if [[ -z "$RESOLVED_IPS" ]]; then
        warn "无法解析域名 $domain 的 A 记录"
    else
        if echo " $RESOLVED_IPS " | grep -q " $SERVER_IP "; then
            ok "域名解析($RESOLVED_IPS) 与本机IP($SERVER_IP) 一致"
        else
            warn "域名解析($RESOLVED_IPS) 与本机IP($SERVER_IP) 不一致，可能导致签发/访问失败"
        fi
    fi
fi

# Port checks
isPort=$(netstat -ntlp 2>/dev/null | grep -E ':80 |:443 ' || true)
if [[ -n "$isPort" ]]; then
    echo
    fail "80 或 443 端口被占用，请先释放端口后重试"
    echo "冲突详情:"; echo "$isPort"
    exit 1
fi
ok "端口检查通过（80/443 未占用）"

echo
read -r -p "确认开始安装并启动 Caddy 服务？(y/N): " confirm
if [[ ! "${confirm,,}" =~ ^y ]]; then
    warn "已取消安装"
    exit 0
fi

step "下载并安装 Caddy..."
curl -fSL https://github.com/spectramaster/v2ray-wss/releases/download/v-monthly/caddy-v-monthly.tar.gz | tar -xz -C /usr/local/
chmod +x /usr/local/caddy
ok "Caddy 安装完成"

step "写入 Caddy 配置..."
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
ok "配置文件: /etc/caddy/https.caddyfile"

step "配置 systemd 服务..."
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
ok "服务文件: /etc/systemd/system/caddy.service"

step "启动服务..."
systemctl daemon-reload
systemctl enable caddy.service >/dev/null 2>&1 || true
systemctl restart caddy.service
sleep 1
if systemctl is-active --quiet caddy.service; then
    ok "Caddy 服务已启动"
else
    fail "Caddy 启动失败，最近日志："
    journalctl -u caddy.service --no-pager -n 50 || true
    exit 1
fi

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
banner
echo -e "${GREEN}安装已经完成${RESET}\n"
echo -e "${BOLD}=========== Https 配置参数 ============${RESET}"
echo "地址：${domain}"
echo "端口：443"
echo "用户：1024"
echo "密码：${Passwd}"
echo -e "${BOLD}======================================${RESET}"
echo "连接字符串："
echo "http=$domain:443, username=1024, password=$Passwd, over-tls=true, tls-verification=true, tls-host=$domain, udp-relay=false, tls13=true, tag=https"
echo
echo "客户端配置已保存到：/etc/caddy/https.txt"
echo
echo -e "${YELLOW}提示：${RESET}"
echo "- 请确保安全组/防火墙放行 TCP 443"
echo "- 首次签发证书可能需要数十秒，如遇 502/403 请稍后重试"
echo "- 查看服务状态：systemctl status caddy --no-pager"
echo "- 查看访问日志/错误：journalctl -u caddy -e --no-pager"
