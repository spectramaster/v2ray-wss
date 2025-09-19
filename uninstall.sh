#!/usr/bin/env bash

set -Eeuo pipefail

GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; RED='\033[31m'; BOLD='\033[1m'; RESET='\033[0m'

banner() {
  clear
  echo -e "${BLUE}${BOLD}==============================================${RESET}"
  echo -e "${BLUE}${BOLD}                卸载与清理工具               ${RESET}"
  echo -e "${BLUE}${BOLD}==============================================${RESET}"
}

confirm() {
  local msg="$1"
  read -r -p "$msg (y/N): " ans
  [[ "${ans,,}" == "y" ]]
}

un_v2ray() {
  echo "停止并禁用 v2ray..."
  systemctl stop v2ray 2>/dev/null || true
  systemctl disable v2ray 2>/dev/null || true
  echo "删除配置文件 /usr/local/etc/v2ray ..."
  rm -rf /usr/local/etc/v2ray 2>/dev/null || true
  echo "保留二进制以免影响其他安装。如需删除可执行文件：rm -f /usr/local/bin/v2ray /usr/local/bin/v2ctl"
  echo -e "${GREEN}v2ray 卸载完成${RESET}"
}

un_nginx() {
  echo "重置 Nginx 配置(将还原为包默认配置，谨慎！)"
  if confirm "继续重置 /etc/nginx/nginx.conf?"; then
    mv -f /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%s) 2>/dev/null || true
    echo "请根据发行版默认模板手动恢复 nginx 配置或重装 nginx 包。"
  fi
  systemctl restart nginx 2>/dev/null || true
  echo -e "${GREEN}Nginx 操作完成${RESET}"
}

un_caddy() {
  echo "停止并禁用 Caddy..."
  systemctl stop caddy 2>/dev/null || true
  systemctl disable caddy 2>/dev/null || true
  echo "删除 Caddy 服务文件与配置(保留二进制)"
  rm -f /etc/systemd/system/caddy.service 2>/dev/null || true
  rm -f /etc/caddy/https.caddyfile /etc/caddy/https.txt 2>/dev/null || true
  systemctl daemon-reload || true
  echo -e "${GREEN}Caddy 卸载完成（/usr/local/caddy 如需删除请手动 rm）${RESET}"
}

un_hysteria() {
  echo "停止并禁用 hysteria-server..."
  systemctl stop hysteria-server 2>/dev/null || true
  systemctl disable hysteria-server 2>/dev/null || true
  echo "删除配置与证书 /etc/hysteria ..."
  rm -rf /etc/hysteria 2>/dev/null || true
  echo -e "${GREEN}Hysteria2 卸载完成${RESET}"
}

un_reality() {
  echo "停止并禁用 xray..."
  systemctl stop xray 2>/dev/null || true
  systemctl disable xray 2>/dev/null || true
  echo "删除配置 /usr/local/etc/xray ..."
  rm -rf /usr/local/etc/xray 2>/dev/null || true
  echo -e "${GREEN}Reality(xray) 卸载完成${RESET}"
}

un_ss() {
  echo "停止并禁用 shadowsocks..."
  systemctl stop shadowsocks 2>/dev/null || true
  systemctl disable shadowsocks 2>/dev/null || true
  rm -rf /etc/shadowsocks 2>/dev/null || true
  echo -e "${GREEN}Shadowsocks-rust 卸载完成（/usr/local/bin/ssserver 如需删除请手动 rm）${RESET}"
}

un_tuning() {
  echo "移除系统调优 drop-in..."
  rm -f /etc/security/limits.d/99-custom.conf 2>/dev/null || true
  rm -f /etc/systemd/system.conf.d/99-limits.conf 2>/dev/null || true
  rm -f /etc/sysctl.d/99-tuning.conf 2>/dev/null || true
  systemctl daemon-reload || true
  sysctl --system || true
  echo -e "${GREEN}系统调优清理完成${RESET}"
}

main_menu() {
  banner
  echo -e "${BOLD}选择要卸载的组件：${RESET}"
  echo "  [1] V2Ray"
  echo "  [2] Nginx 反代配置(重置)"
  echo "  [3] Caddy (HTTPS 代理)"
  echo "  [4] Hysteria2"
  echo "  [5] Reality (Xray)"
  echo "  [6] Shadowsocks-rust"
  echo "  [7] 系统调优 (tcp-window)"
  echo "  [0] 退出"
  read -r -p "输入数字并回车: " n
  case "$n" in
    1) confirm "确认卸载 v2ray?" && un_v2ray ;;
    2) confirm "确认重置 nginx 配置?" && un_nginx ;;
    3) confirm "确认卸载 caddy?" && un_caddy ;;
    4) confirm "确认卸载 hysteria2?" && un_hysteria ;;
    5) confirm "确认卸载 reality(xray)?" && un_reality ;;
    6) confirm "确认卸载 shadowsocks-rust?" && un_ss ;;
    7) confirm "确认移除系统调优?" && un_tuning ;;
    0) exit 0 ;;
    *) echo -e "${YELLOW}无效选择${RESET}" ;;
  esac
}

main_menu
