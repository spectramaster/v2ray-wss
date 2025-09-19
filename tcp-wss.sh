#!/usr/bin/env bash
# forum: https://1024.day

set -Eeuo pipefail
trap 'echo "[ERROR] Command failed at line $LINENO" >&2' ERR

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "Error: This script must be run as root!" 1>&2
    exit 1
fi

# ---------- UI & Helpers ----------
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
MAGENTA='\033[35m'

banner() {
    clear
    echo -e "${MAGENTA}${BOLD}==============================================${RESET}"
    echo -e "${MAGENTA}${BOLD}      多协议网络代理 一键安装管理面板      ${RESET}"
    echo -e "${MAGENTA}${BOLD}==============================================${RESET}"
    echo -e "${BLUE}  支持：Shadowsocks-rust / V2Ray+WS+TLS / Reality / Hysteria2 / HTTPS  ${RESET}"
}

get_server_ip() { command get_server_ip; }
validate_domain() { command validate_domain "$1"; }
rand_path() { command rand_path; }
gen_uuid() { command gen_uuid; }
choose_free_port() { command choose_free_port; }

# ---------- Globals ----------
v2path="$(rand_path)"
v2uuid="$(gen_uuid)"
V2_UPSTREAM_PORT="$(choose_free_port)"

install_precheck(){
    echo "==== 输入已经 DNS 解析好的域名 ===="
    if [[ -n "${DOMAIN:-}" ]]; then
      domain="$DOMAIN"; echo "$domain";
    else
      read -r domain
    fi
    if [[ -z "$domain" ]] || ! validate_domain "$domain"; then
        echo "域名格式无效" >&2; exit 1
    fi

    if [[ -n "${PORT:-}" ]]; then
      getPort="$PORT"
    else
      read -r -t 15 -p "回车或等待15秒为默认端口443，或者自定义端口请输入(1-65535)："  getPort || true
    fi
    if [[ -z "${getPort:-}" ]]; then getPort=443; fi
    if ! [[ "$getPort" =~ ^[0-9]+$ ]] || (( getPort < 1 || getPort > 65535 )); then
        echo "端口无效" >&2; exit 1
    fi

    # Install minimal deps
    if command_exists apt-get; then
        apt-get update -y
        apt-get install -y net-tools curl nginx cron socat
    elif command_exists dnf; then
        dnf makecache -y || true
        dnf install -y net-tools curl nginx cronie socat
    else
        yum makecache -y || true
        yum install -y epel-release || true
        yum install -y net-tools curl nginx cronie socat
    fi

    # Check 80 and target port
    sleep 1
    local conflicts
    conflicts=$(netstat -ntlp 2>/dev/null | grep -E ":80 |:${getPort} ") || true
    if [[ -n "$conflicts" ]]; then
        echo " ================================================== "
        echo " 80或目标端口(${getPort})被占用，请先释放端口再运行此脚本"
        echo
        echo " 端口占用信息如下："
        echo "$conflicts"
        echo " ================================================== "
        exit 1
    fi

    # Verify domain resolves to this server (acme standalone requires direct mapping)
    SERVER_IP=$(get_server_ip)
    RESOLVED_IPS=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}' | tr '\n' ' ')
    if [[ -z "$RESOLVED_IPS" ]]; then
        echo "警告：无法解析域名 $domain 的 A 记录" >&2
    elif ! echo " $RESOLVED_IPS " | grep -q " $SERVER_IP "; then
        echo "警告：域名解析的IP($RESOLVED_IPS)与本机IP($SERVER_IP)不匹配，acme standalone 可能失败" >&2
    fi
}

install_nginx(){
cat >/etc/nginx/nginx.conf<<EOF
pid /var/run/nginx.pid;
worker_processes auto;
worker_rlimit_nofile 51200;
events {
    worker_connections 1024;
    multi_accept on;
}
http {
    server_tokens off;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 120s;
    keepalive_requests 10000;
    types_hash_max_size 2048;
    include /etc/nginx/mime.types;
    access_log off;
    error_log /dev/null;

    server {
        listen 80;
        listen [::]:80;
        server_name $domain;
        location / {
            return 301 https://\$server_name\$request_uri;
        }
    }
    
    server {
        listen $getPort ssl http2;
        listen [::]:$getPort ssl http2;
        server_name $domain;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:
                     ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:
                     ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;
        ssl_stapling on;
        ssl_stapling_verify on;
        resolver 1.1.1.1 1.0.0.1 8.8.8.8 valid=300s;
        resolver_timeout 5s;
        ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
        location / {
            default_type text/plain;
            return 200 "Hello World !";
        }
        location /$v2path {
            proxy_redirect off;
            proxy_pass http://127.0.0.1:$V2_UPSTREAM_PORT;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$http_host;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_read_timeout 300s;
            proxy_send_timeout 300s;
        }
    }
}
EOF
    nginx -t
    systemctl enable nginx.service
}

acme_ssl(){    
    curl -fsSL https://get.acme.sh | sh -s email=my@example.com
    mkdir -p "/etc/letsencrypt/live/$domain"
    # Ensure nginx is stopped for standalone
    systemctl stop nginx || true
    ~/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256
    ~/.acme.sh/acme.sh --installcert -d "$domain" --ecc \
        --fullchain-file "/etc/letsencrypt/live/$domain/fullchain.pem" \
        --key-file "/etc/letsencrypt/live/$domain/privkey.pem"
}

install_v2ray(){    
    mkdir -p /usr/local/etc/v2ray
    local url="${V2RAY_INSTALL_URL:-https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh}"
    curl -fsSL "$url" | bash
    
cat >/usr/local/etc/v2ray/config.json<<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": $V2_UPSTREAM_PORT,
      "protocol": "vmess",
      "settings": { "clients": [ { "id": "$v2uuid" } ] },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "/$v2path" }
      }
    }
  ],
  "outbounds": [ { "protocol": "freedom", "settings": {} } ]
}
EOF

    systemctl daemon-reload
    systemctl enable v2ray.service
    if ! test_v2ray_config "/usr/local/etc/v2ray/config.json"; then
        echo -e "${WARN} v2ray 配置验证失败，尝试继续" >&2
    fi
    systemctl restart v2ray.service
    ensure_service_active v2ray.service "v2ray" || true
    systemctl restart nginx.service

cat >/usr/local/etc/v2ray/client.txt<<EOF
=========== 配置参数 =============
协议：VMess
地址：${domain}
端口：${getPort}
UUID：${v2uuid}
加密方式：auto
传输协议：ws
路径：/${v2path}
底层传输：tls
注意：回源端口为 ${V2_UPSTREAM_PORT}
=================================
EOF
}

install_ssrust(){
    wget https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/ss-rust.sh && bash ss-rust.sh
}

install_reality(){
    wget https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/reality.sh && bash reality.sh
}

install_hy2(){
    wget https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/hy2.sh && bash hy2.sh
}

install_https(){
    wget https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/https.sh && bash https.sh
}

client_v2ray(){
    local link_json
    link_json=$(printf '{"port":%s,"ps":"1024-wss","tls":"tls","id":"%s","aid":0,"v":2,"host":"%s","type":"none","path":"/%s","net":"ws","add":"%s","allowInsecure":0,"method":"auto","peer":"%s","sni":"%s"}' \
        "$getPort" "$v2uuid" "$domain" "$v2path" "$domain" "$domain" "$domain")
    wslink=$(echo -n "$link_json" | base64_noline)

    echo
    echo "安装已经完成"
    echo
    echo "=========== v2ray 配置参数 ============"
    echo "协议：VMess"
    echo "地址：${domain}"
    echo "端口：${getPort}"
    echo "UUID：${v2uuid}"
    echo "加密方式：auto"
    echo "传输协议：ws"
    echo "路径：/${v2path}"
    echo "底层传输：tls"
    echo "======================================"
    echo "vmess://${wslink}"
    echo
}

start_menu(){
    banner
    echo
    echo -e "${BOLD}请选择要执行的操作：${RESET}"
    echo -e "  ${CYAN}[1]${RESET} ${BOLD}安装 Shadowsocks-rust${RESET} ${YELLOW}(用于落地)${RESET}"
    echo -e "  ${CYAN}[2]${RESET} ${BOLD}安装 V2Ray + WS + TLS${RESET}"
    echo -e "  ${CYAN}[3]${RESET} ${BOLD}安装 Reality${RESET}"
    echo -e "  ${CYAN}[4]${RESET} ${BOLD}安装 Hysteria2${RESET}"
    echo -e "  ${CYAN}[5]${RESET} ${BOLD}安装 HTTPS 正向代理${RESET}"
    echo -e "  ${CYAN}[0]${RESET} 退出"
    echo
    read -r -p "请输入数字并回车: " num
    case "$num" in
    1)
    install_ssrust
    ;;
    2)
    install_precheck
    install_nginx
    acme_ssl
    install_v2ray
    client_v2ray
    ;;
    3)
    install_reality
    ;;
    4)
    install_hy2
    ;;
    5)
    install_https
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    echo "请输入正确数字"
    sleep 2s
    start_menu
    ;;
    esac
}

start_menu
