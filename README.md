# 一键代理脚本 | V2Ray + WS/TLS · Reality · Hysteria2 · HTTPS

> 简洁、现代、稳健的一键脚本集合。支持 Debian/Ubuntu/CentOS 及 ARM 架构（甲骨文等）。

- 无域名：建议使用 Reality、Hysteria2
- 有域名：建议使用 V2Ray + WS + TLS 或 HTTPS 正向代理

---

## 快速开始（复制即用）

- 主菜单（推荐）：一键安装/管理多种代理
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/tcp-wss.sh)"
```

- 单独安装 V2Ray + WebSocket（免 TLS 直连）
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/ws.sh)"
```

- 单独安装 Reality
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/reality.sh)"
```

- 单独安装 Hysteria2
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/hy2.sh)"
```

- 单独安装 HTTPS 正向代理（Caddy）
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/https.sh)"
```

- 应用 TCP/系统优化（需确认）
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/tcp-window.sh)"
```

---

## 功能亮点
- 一键安装，零克隆操作，复制命令即可运行
- 统一 Bash 严格模式与错误捕获，失败可见、问题可排
- 友好终端界面：彩色横幅、分步提示、安装总结
- 多系统支持：Debian/Ubuntu/CentOS/RHEL/Alma/Rocky/openSUSE/Arch
- IPv4/IPv6 自适应，域名解析一致性检测与端口占用检查
- 安装完成自动输出客户端连接信息与保存路径

---

## 已测试系统
- Debian 9/10/11/12
- Ubuntu 16.04/18.04/20.04/22.04
- CentOS 7

---

## 安装完成后（查看客户端配置）
- V2Ray + WS：
```
cat /usr/local/etc/v2ray/client.txt
```
- Shadowsocks-rust：
```
cat /etc/shadowsocks/config.json
```
- Reality：
```
cat /usr/local/etc/xray/reclient.json
```
- Hysteria2：
```
cat /etc/hysteria/hyclient.json
```
- HTTPS 正向代理（Caddy）：
```
cat /etc/caddy/https.txt
```

---

## 常见问题与提示
- 域名需正确解析到本机，80/443 端口需空闲
- 云服务器需在安全组放行相应端口（TCP 443，或自定义端口；Hysteria2 需放行 UDP）
- 查看服务状态与日志：
```
systemctl status v2ray --no-pager
systemctl status caddy --no-pager
systemctl status hysteria-server --no-pager
journalctl -u v2ray -e --no-pager
journalctl -u caddy -e --no-pager
journalctl -u hysteria-server -e --no-pager
```

---

## 变更说明（重要）
- 脚本统一为 Bash，增加严格模式和错误处理，提升稳健性
- 客户端信息文件统一为可读文本（.txt），附带连接链接
- tcp-window.sh 采用安全的 drop‑in 配置，执行前有确认提示，不再强制重启

---

## 卸载
- 文档： https://1024.day/d/1296
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/uninstall.sh)"
```

---

## 非交互安装（可选）
- tcp-wss.sh：
```
DOMAIN=your.domain PORT=443 bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/tcp-wss.sh)"
```
- https.sh：
```
DOMAIN=your.domain ACCEPT=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/https.sh)"
```
- hy2.sh：
```
SERVER_PORT=443 SNI=bing.com HY2_USE_ACME=1 DOMAIN=your.domain bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/hy2.sh)"
```

---

## English
For English documentation, see README.en.md.

---

## 示例输出

以下为安装完成后的终端输出示例（文本模拟）。实际显示为彩色横幅与有序分步提示。

V2Ray + WS 安装完成示例（ws.sh）
```
==============================================
           V2Ray WebSocket 快速安装           
==============================================

安装已经完成

=========== V2Ray 配置参数 ============
协议：VMess
地址：203.0.113.10
端口：31921
UUID：123e4567-e89b-12d3-a456-426614174000
加密方式：auto
传输协议：ws
路径：/f3a9b1c2
注意：不需要打开 TLS
======================================
连接链接：
vmess://<base64-encoded-config>
```

HTTPS 正向代理安装完成示例（https.sh）
```
==============================================
        Caddy HTTPS 正向代理 一键安装         
==============================================

安装已经完成

=========== Https 配置参数 ============
地址：example.com
端口：443
用户：1024
密码：k9m3z4p1q8ab
======================================
连接字符串：
http=example.com:443, username=1024, password=k9m3z4p1q8ab, over-tls=true, tls-verification=true, tls-host=example.com, udp-relay=false, tls13=true, tag=https
```

Reality 安装完成示例（reality.sh）
```
==============================================
                Reality 一键安装               
==============================================

安装已经完成

=========== Reality 配置参数 ============
代理模式：vless
地址：203.0.113.10
端口：443
UUID：123e4567-e89b-12d3-a456-426614174000
流控：xtls-rprx-vision
传输协议：tcp
Public key：F6bS0zQ0y8yWg3i0k4bIYfS9i2bbqXl5l1m2o3p4q5r
底层传输：reality
SNI：www.amazon.com
shortIds：88
========================================
客户端连接链接：
vless://123e4567-e89b-12d3-a456-426614174000@203.0.113.10:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.amazon.com&fp=chrome&pbk=F6bS0zQ0y8yWg3i0k4bIYfS9i2bbqXl5l1m2o3p4q5r&sid=88&type=tcp&headerType=none#1024-reality
```

注：IP、端口、UUID、路径、密码等均为示例值，实际以安装输出为准。

---

## 其它
- 便宜 VPS 推荐：https://hostalk.net/deals.html
- 预览图：

![image](https://github.com/user-attachments/assets/0b6db263-a8ee-48c5-8605-048e3e25c967)
