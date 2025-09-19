#!/usr/bin/env bash
# forum: https://1024.day

set -Eeuo pipefail
trap 'echo "[ERROR] Command failed at line $LINENO" >&2' ERR

# Root check
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "Error: This script must be run as root!" 1>&2
    exit 1
fi

# ---------- Helpers ----------
command_exists() { command -v "$1" >/dev/null 2>&1; }

base64_noline() {
    if base64 --help 2>&1 | grep -q '\-w, \--wrap'; then
        base64 -w 0
    else
        base64 | tr -d '\n'
    fi
}

get_ip() {
    local ip=""
    # Prefer IPv4; fallback IPv6
    local sources_v4=(
        "http://www.cloudflare.com/cdn-cgi/trace"
        "https://api.ipify.org"
        "https://ipinfo.io/ip"
        "https://ipv4.icanhazip.com/"
        "https://checkip.amazonaws.com"
    )
    for src in "${sources_v4[@]}"; do
        if [[ "$src" == *cloudflare* ]]; then
            ip=$(curl -fsS4 --connect-timeout 10 --max-time 15 "$src" | awk -F'=' '/^ip=/{print $2}' | tr -d '\r\n' || true)
        else
            ip=$(curl -fsS4 --connect-timeout 10 --max-time 15 "$src" | tr -d '\r\n' || true)
        fi
        [[ -n "$ip" ]] && break || true
    done
    if [[ -z "$ip" ]]; then
        ip=$(curl -fsS6 --connect-timeout 10 --max-time 15 "http://www.cloudflare.com/cdn-cgi/trace" | awk -F'=' '/^ip=/{print $2}' | tr -d '\r\n' || true)
    fi
    echo "${ip}"
}

is_port_in_use() {
    local port="$1"
    if command_exists ss; then
        ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE ":${port}$"
    elif command_exists netstat; then
        netstat -lnt 2>/dev/null | awk '{print $4}' | grep -qE ":${port}$"
    elif command_exists lsof; then
        lsof -iTCP -sTCP:LISTEN -nP 2>/dev/null | grep -q ":${port}"
    else
        return 1
    fi
}

choose_free_port() {
    local try=0 port
    while (( try < 30 )); do
        port=$(shuf -i 2000-65000 -n 1)
        if ! is_port_in_use "$port"; then
            echo "$port"
            return 0
        fi
        ((try++))
    done
    # fallback
    echo 33445
}

gen_uuid() {
    if [[ -r /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    elif command_exists uuidgen; then
        uuidgen
    else
        date +%s%N | md5sum | awk '{print $1"-0000-4000-8000-"substr($1,1,12)}'
    fi
}

rand_path() {
    if command_exists openssl; then
        openssl rand -hex 8
    else
        head -c 16 /dev/urandom | md5sum | head -c 12
    fi
}

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
    curl -fsSL https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh | bash

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
    systemctl restart v2ray.service

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

    echo
    echo "安装已经完成"
    echo
    echo "=========== v2ray 配置参数 ============"
    echo "协议：VMess"
    echo "地址：${SERVER_IP}"
    echo "端口：${v2port}"
    echo "UUID：${v2uuid}"
    echo "加密方式：auto"
    echo "传输协议：ws"
    echo "路径：/${v2path}"
    echo "注意：不需要打开 TLS"
    echo "======================================"
    echo "vmess://${wslink}"
    echo
}

# ---------- Main ----------
SERVER_IP="$(get_ip)"
v2uuid="$(gen_uuid)"
v2path="$(rand_path)"
v2port="$(choose_free_port)"

install_update
install_v2ray
client_v2ray
