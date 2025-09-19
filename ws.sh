#!/usr/bin/env bash
# forum: https://1024.day

set -Eeuo pipefail
trap 'echo "[ERROR] Command failed at line $LINENO" >&2' ERR

# Root check
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
    # remote fallback
    # shellcheck disable=SC1090
    source <(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/scripts/lib/common.sh)
  fi
fi

banner() {
    clear
    echo -e "${CYAN}${BOLD}==============================================${RESET}"
    echo -e "${CYAN}${BOLD}           V2Ray WebSocket 快速安装           ${RESET}"
    echo -e "${CYAN}${BOLD}==============================================${RESET}"
}
get_ip() { get_server_ip; }

install_update() { 
    if command_exists apt-get; then
        apt-get update -y
        apt-get install -y gawk curl
    elif command_exists dnf; then
        dnf makecache -y || true
        dnf install -y gawk curl
    elif command_exists yum; then
        yum makecache -y || true
        yum install -y epel-release || true
        yum install -y gawk curl
    else
        echo "Warning: Unknown package manager. Please ensure curl and gawk are installed." >&2
    fi
}

install_v2ray(){
    mkdir -p /usr/local/etc/v2ray
    local url="${V2RAY_INSTALL_URL:-https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh}"
    curl -fsSL "$url" | bash

cat >/usr/local/etc/v2ray/config.json<<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": $v2port,
      "protocol": "vmess",
      "settings": {
        "clients": [
          { "id": "$v2uuid" }
        ]
      },
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
    # Validate config before restart
    if ! test_v2ray_config "/usr/local/etc/v2ray/config.json"; then
        echo -e "${CROSS} v2ray 配置验证失败" >&2
    fi
    systemctl restart v2ray.service
    ensure_service_active v2ray.service "v2ray" || true
    ensure_service_active v2ray.service "v2ray" || true

    # Save human-readable client info
cat >/usr/local/etc/v2ray/client.txt<<EOF
=========== 配置参数 =============
协议：VMess
地址：${SERVER_IP}
端口：${v2port}
UUID：${v2uuid}
加密方式：auto
传输协议：ws
路径：/${v2path}
注意：不需要打开 TLS
=================================
EOF
}

client_v2ray(){
    local link_json
    link_json=$(printf '{"port":%s,"ps":"1024-ws","id":"%s","aid":0,"v":2,"add":"%s","type":"none","path":"/%s","net":"ws","method":"auto"}' \
        "$v2port" "$v2uuid" "$SERVER_IP" "$v2path")
    wslink=$(echo -n "$link_json" | base64_noline)

    banner
    echo -e "${GREEN}安装已经完成${RESET}\n"
    echo -e "${BOLD}=========== V2Ray 配置参数 ============${RESET}"
    echo "协议：VMess"
    echo "地址：${SERVER_IP}"
    echo "端口：${v2port}"
    echo "UUID：${v2uuid}"
    echo "加密方式：auto"
    echo "传输协议：ws"
    echo "路径：/${v2path}"
    echo "注意：不需要打开 TLS"
    echo -e "${BOLD}======================================${RESET}"
    echo -e "连接链接：\nvmess://${wslink}\n"
}

# ---------- Main ----------
SERVER_IP="$(get_ip)"
v2uuid="$(gen_uuid)"
v2path="$(rand_path)"
v2port="$(choose_free_port)"

install_update
install_v2ray
client_v2ray
