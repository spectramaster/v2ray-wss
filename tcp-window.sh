#!/usr/bin/env bash
# Issues https://1024.day

set -Eeuo pipefail
trap 'echo "[ERROR] Command failed at line $LINENO" >&2' ERR

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "Error: This script must be run as root!"
    exit 1
fi

GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; BOLD='\033[1m'; RESET='\033[0m'
banner() {
    clear
    echo -e "${BLUE}${BOLD}==============================================${RESET}"
    echo -e "${BLUE}${BOLD}              系统网络参数调优               ${RESET}"
    echo -e "${BLUE}${BOLD}==============================================${RESET}"
}

banner
echo -e "将应用适度的文件句柄/进程数限制与 TCP/BBR 优化。\n"
read -r -p "确认应用内核与系统调优设置？(y/N): " CONFIRM
if [[ ! "${CONFIRM,,}" =~ ^y ]]; then
    echo -e "${YELLOW}已取消${RESET}"
    exit 0
fi

# 1) limits 配置，使用 drop-in，避免覆盖系统默认文件
mkdir -p /etc/security/limits.d
cat >/etc/security/limits.d/99-custom.conf<<EOF
* soft     nproc    131072
* hard     nproc    131072
* soft     nofile   262144
* hard     nofile   262144

root soft  nproc    131072
root hard  nproc    131072
root soft  nofile   262144
root hard  nofile   262144
EOF

# 2) pam_limits 挂载，幂等追加
grep -q "pam_limits.so" /etc/pam.d/common-session 2>/dev/null || echo "session required pam_limits.so" >> /etc/pam.d/common-session
grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive 2>/dev/null || echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive

# 3) systemd limits，使用 drop-in 文件
mkdir -p /etc/systemd/system.conf.d
cat >/etc/systemd/system.conf.d/99-limits.conf<<EOF
[Manager]
DefaultLimitNOFILE=262144
DefaultLimitNPROC=131072
EOF

# 4) sysctl 调优，使用独立文件
mkdir -p /etc/sysctl.d
TUNE_FILE=/etc/sysctl.d/99-tuning.conf
cat >"$TUNE_FILE"<<EOF
fs.file-max = 524288
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
#net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rmem = 8192 262144 536870912
net.ipv4.tcp_wmem = 4096 16384 536870912
#net.ipv4.udp_rmem_min = 8192
#net.ipv4.udp_wmem_min = 8192
net.ipv4.tcp_adv_win_scale = -2
net.ipv4.tcp_notsent_lowat = 131072
#net.ipv6.conf.all.disable_ipv6 = 1
#net.ipv6.conf.default.disable_ipv6 = 1
#net.ipv6.conf.lo.disable_ipv6 = 1
#net.ipv4.ip_forward = 1
EOF

# 5) 使配置生效
systemctl daemon-reload || true
sysctl -p "$TUNE_FILE" || true

echo -e "${GREEN}已应用系统调优设置${RESET}"
echo "建议重启以完全生效（尤其是 systemd limits）。"
