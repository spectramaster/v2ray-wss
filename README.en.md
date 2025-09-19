One-Click Proxies | V2Ray + WS/TLS · Reality · Hysteria2 · HTTPS

> Minimal, modern, and robust one-liner scripts. Support Debian/Ubuntu/CentOS and ARM (Oracle, etc.).

- No domain: Reality, Hysteria2 recommended
- With domain: V2Ray + WS + TLS or HTTPS forward proxy recommended

---

Quick Start (copy & run)

- Main menu (recommended):
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/tcp-wss.sh)"
```

- Install V2Ray + WebSocket (no TLS):
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/ws.sh)"
```

- Install Reality:
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/reality.sh)"
```

- Install Hysteria2:
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/hy2.sh)"
```

- Install HTTPS forward proxy (Caddy):
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/https.sh)"
```

- Apply TCP/system tuning (confirmation required):
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/spectramaster/v2ray-wss/main/tcp-window.sh)"
```

---

Highlights

- One-liners, no clone needed
- Strict bash mode and error trapping
- Friendly terminal UI with banners and summaries
- Broad distro support
- IPv4/IPv6-aware, DNS and port checks
- Client info and import links saved after install

---

After Installation (where to find client info)

- V2Ray + WS: `/usr/local/etc/v2ray/client.txt`
- Shadowsocks-rust: `/etc/shadowsocks/config.json` and `/etc/shadowsocks/client.txt`
- Reality: `/usr/local/etc/xray/reclient.json`
- Hysteria2: `/etc/hysteria/hyclient.json`
- HTTPS (Caddy): `/etc/caddy/https.txt`

---

Non-interactive usage

You can export environment variables to skip prompts:
- tcp-wss.sh: `DOMAIN`, `PORT`
- https.sh: `DOMAIN`, `ACCEPT=1`
- hy2.sh: `SERVER_PORT`, `SNI`, optionally `HY2_USE_ACME=1` and `DOMAIN`
- ws.sh: random port/path/uuid are auto-generated

---

Troubleshooting

Check services and logs:
```
systemctl status v2ray --no-pager
systemctl status caddy --no-pager
systemctl status hysteria-server --no-pager
journalctl -u v2ray -e --no-pager
journalctl -u caddy -e --no-pager
journalctl -u hysteria-server -e --no-pager
```

Run `DOMAIN=your.domain bash diagnose.sh` to perform quick checks.

---

Changes

- Unified bash strict mode and error handling
- Client info saved as readable `.txt` with import links
- Safe drop-in tuning for tcp-window.sh

