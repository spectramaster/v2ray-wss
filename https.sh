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
# Load common helpers
if [[ -z "${COMMON_LOADED:-}" ]]; then
  if [[ -f "$(dirname "$0")/scripts/lib/common.sh" ]]; then
    # shellcheck source=/dev/null
    source "$(dirname "$0")/scripts/lib/common.sh"
  else
    # shellcheck disable=SC1090
    source <(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/scripts/lib/common.sh)
  fi
fi

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

validate_domain() { command validate_domain "$1"; }

Passwd=$(head -c 16 /dev/urandom | md5sum | head -c 12)

banner
step "准备安装..."

echo -e "\n${BOLD}请输入已完成 DNS 解析的域名：${RESET}"
if [[ -n "${DOMAIN:-}" ]]; then
  domain="$DOMAIN"
  echo "> $domain"
else
  read -r -p "> " domain
fi
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
if [[ -n "${ACCEPT:-}" && "${ACCEPT}" =~ ^(1|y|Y|yes|YES)$ ]]; then
  confirm="y"
  echo "确认：Y"
else
  read -r -p "确认开始安装并启动 Caddy 服务？(y/N): " confirm
fi
if [[ ! "${confirm,,}" =~ ^y ]]; then
    warn "已取消安装"
    exit 0
fi

step "下载并安装 Caddy..."
curl -fSL "${CADDY_BUNDLE_URL:-https://github.com/spectramaster/v2ray-wss/releases/download/v-monthly/caddy-v-monthly.tar.gz}" | tar -xz -C /usr/local/
chmod +x /usr/local/caddy
ok "Caddy 下载完成"

step "创建非 root 运行用户（caddy）..."
if ! id -u caddy >/dev/null 2>&1; then
  useradd -r -g nogroup -d /var/lib/caddy -s /usr/sbin/nologin caddy 2>/dev/null || \
  useradd -r -M -s /usr/sbin/nologin caddy 2>/dev/null || true
fi
mkdir -p /etc/caddy /var/lib/caddy
chown -R caddy:caddy /etc/caddy /var/lib/caddy 2>/dev/null || chown -R caddy:root /etc/caddy /var/lib/caddy 2>/dev/null || true

step "赋予低端口绑定能力..."
if command -v setcap >/dev/null 2>&1; then
  setcap 'cap_net_bind_service=+ep' /usr/local/caddy || true
else
  # 尝试安装 setcap 工具
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y && apt-get install -y libcap2-bin || true
  elif command -v yum >/dev/null 2>&1; then
    yum install -y libcap || yum install -y libcap-progs || true
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y libcap || dnf install -y libcap-progs || true
  fi
  command -v setcap >/dev/null 2>&1 && setcap 'cap_net_bind_service=+ep' /usr/local/caddy || true
fi
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
User=caddy
Group=caddy
ExecStart=/usr/local/caddy run --environ --config /etc/caddy/https.caddyfile
ExecReload=/usr/local/caddy reload --config /etc/caddy/https.caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

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
