#!/usr/bin/env bash

set -Eeuo pipefail

if [[ -z "${COMMON_LOADED:-}" ]]; then
  if [[ -f "$(dirname "$0")/scripts/lib/common.sh" ]]; then
    # shellcheck source=/dev/null
    source "$(dirname "$0")/scripts/lib/common.sh"
  else
    # shellcheck disable=SC1090
    source <(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/scripts/lib/common.sh)
  fi
fi

echo -e "${BLUE}${BOLD}== 基本信息 ==${RESET}"
echo "Hostname: $(hostname)"
echo "IP(v4): $(get_server_ip)"
echo "Kernel: $(uname -r)"
echo "OS: $(grep -E '^PRETTY_NAME' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || lsb_release -ds 2>/dev/null || echo unknown)"
echo

check_port() {
  local port="$1" label="$2"
  if is_port_in_use "$port"; then
    echo -e "${CHECK} 端口 $port (${label}) 正在监听"
  else
    echo -e "${WARN} 端口 $port (${label}) 未监听"
  fi
}

echo -e "${BLUE}${BOLD}== 服务状态 ==${RESET}"
for svc in v2ray xray caddy hysteria-server; do
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    if systemctl is-active --quiet "$svc"; then
      echo -e "${CHECK} $svc 运行中"
    else
      echo -e "${WARN} $svc 未运行"
    fi
  fi
done
echo

echo -e "${BLUE}${BOLD}== 常见端口检查 ==${RESET}"
check_port 80 HTTP
check_port 443 HTTPS
check_port 8080 WS-Upstream
echo

echo -e "${BLUE}${BOLD}== 域名解析一致性 ==${RESET}"
if [[ -n "${DOMAIN:-}" ]]; then
  echo "DOMAIN: $DOMAIN"
  resolved=$(resolve_domain_ips "$DOMAIN" | tr '\n' ' ')
  server_ip=$(get_server_ip)
  echo "解析到: $resolved"
  echo "本机IP: $server_ip"
  if echo " $resolved " | grep -q " $server_ip "; then
    echo -e "${CHECK} 一致"
  else
    echo -e "${WARN} 不一致"
  fi
else
  echo "未设置 DOMAIN 环境变量，跳过。使用: DOMAIN=example.com bash diagnose.sh"
fi
echo

echo -e "${BLUE}${BOLD}== 证书文件 ==${RESET}"
for f in /etc/letsencrypt/live/*/fullchain.pem /etc/hysteria/server.crt; do
  if [[ -f "$f" ]]; then
    echo -e "${CHECK} 存在: $f"
  fi
done

echo -e "\n完成。"

