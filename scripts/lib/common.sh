#!/usr/bin/env bash

# Common helpers for installer scripts

# Colors & symbols
export GREEN='\033[32m'; export RED='\033[31m'; export YELLOW='\033[33m'; export CYAN='\033[36m'; export BLUE='\033[34m'; export MAGENTA='\033[35m'; export BOLD='\033[1m'; export RESET='\033[0m'
export CHECK="${GREEN}✓${RESET}"; export CROSS="${RED}✗${RESET}"; export WARN="${YELLOW}!${RESET}"

command_exists() { command -v "$1" >/dev/null 2>&1; }

base64_noline() {
    if base64 --help 2>&1 | grep -q '\-w, \--wrap'; then
        base64 -w 0
    else
        base64 | tr -d '\n'
    fi
}

validate_domain() {
    local d="$1"
    [[ "$d" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]
}

resolve_domain_ips() {
    local host="$1"
    getent hosts "$host" 2>/dev/null | awk '{print $1}' | sort -u
}

get_server_ip() {
    local ip=""
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
    echo "$ip"
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
            echo "$port"; return 0
        fi
        ((try++))
    done
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

ensure_service_active() {
    local svc="$1"; shift || true
    local name="${1:-$svc}"
    if systemctl is-active --quiet "$svc"; then
        echo -e "${CHECK} ${name} 服务已启动"
        return 0
    fi
    echo -e "${CROSS} ${name} 服务未启动，显示最近日志："
    systemctl status "$svc" --no-pager || true
    journalctl -u "$svc" --no-pager -n 50 || true
    return 1
}

test_v2ray_config() {
    local cfg="$1"
    if command_exists v2ray; then
        v2ray run -test -config "$cfg" >/dev/null 2>&1
    else
        /usr/local/bin/v2ray run -test -config "$cfg" >/dev/null 2>&1
    fi
}

test_xray_config() {
    local cfg="$1"
    if command_exists xray; then
        xray run -test -config "$cfg" >/dev/null 2>&1
    else
        /usr/local/bin/xray run -test -config "$cfg" >/dev/null 2>&1
    fi
}

export COMMON_LOADED=1
