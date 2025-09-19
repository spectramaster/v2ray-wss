搭建 Shadowsocks-rust， V2ray+ Nginx + WebSocket 和 Reality, Hysteria2, https 正向代理脚本，支持 Debian、Ubuntu、Centos，并支持甲骨文ARM平台。

简单点讲，没域名的用户可以安装 Reality 和 hy2 代理，有域名的可以安装 V2ray+wss 和 https 正向代理，各取所需。

运行脚本：

```
wget git.io/tcp-wss.sh && bash tcp-wss.sh
```

**便宜VPS推荐：** https://hostalk.net/deals.html

![image](https://github.com/user-attachments/assets/0b6db263-a8ee-48c5-8605-048e3e25c967)

已测试系统如下：

Debian 9, 10, 11, 12

Ubuntu 16.04, 18.04, 20.04, 22.04

CentOS 7

* WSS客户端配置信息保存在：
`cat /usr/local/etc/v2ray/client.txt`

* Shadowsocks客户端配置信息：
`cat /etc/shadowsocks/config.json`

* Reality客户端配置信息保存在：
`cat /usr/local/etc/xray/reclient.json`

* Hysteria2客户端配置信息保存在：
`cat /etc/hysteria/hyclient.json`

* Https正向代理客户端配置信息保存在：
`cat /etc/caddy/https.txt`

变更说明：
- 脚本统一为 Bash，增加严格模式和错误处理，提升稳健性。
- 客户端信息文件从“.json”更名为“.txt”，内容为可读文本与链接。
- tcp-window.sh 采用安全的 drop-in 配置，执行前有确认提示，不再强制重启。

卸载方法如下：
https://1024.day/d/1296

**提醒：连不上的朋友，建议先检查一下服务器自带防火墙有没有关闭？**
