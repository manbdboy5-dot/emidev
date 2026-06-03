#!/bin/bash

# emidev - Complete Automatic Installer with SSL
# এক ক্লিকে সবকিছু রেডি - প্যানেলে কিছু সেটাপ লাগবে না

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Root ইউজার হতে হবে! sudo ব্যবহার করুন${NC}"
   exit 1
fi

clear

# Banner
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                              ║${NC}"
echo -e "${BLUE}║     ${GREEN}███████ ███    ███ ██ ██████  ███████ ██    ██${BLUE}      ║${NC}"
echo -e "${BLUE}║     ${GREEN}██      ████  ████ ██ ██   ██ ██      ██    ██${BLUE}      ║${NC}"
echo -e "${BLUE}║     ${GREEN}█████   ██ ████ ██ ██ ██   ██ █████   ██    ██${BLUE}      ║${NC}"
echo -e "${BLUE}║     ${GREEN}██      ██  ██  ██ ██ ██   ██ ██       ██  ██${BLUE}       ║${NC}"
echo -e "${BLUE}║     ${GREEN}███████ ██      ██ ██ ██████  ███████    ████${BLUE}       ║${NC}"
echo -e "${BLUE}║                                                              ║${NC}"
echo -e "${BLUE}║        ${YELLOW}Complete Auto Installer - X-UI + SSL + Xray${BLUE}        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get user input
echo -e "${YELLOW}🔧 কিছু তথ্য দিন:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Get server IP
SERVER_IP=$(curl -s -4 https://api.ipify.org 2>/dev/null)
if [[ -z "$SERVER_IP" ]]; then
    SERVER_IP=$(curl -s -4 ipv4.icanhazip.com 2>/dev/null)
fi

echo -e "${CYAN}🌐 আপনার সার্ভার IP: ${GREEN}$SERVER_IP${NC}"

read -p "$(echo -e ${YELLOW}👉 আপনার ডোমেইন নাম লিখুন (যেটা $SERVER_IP এ পয়েন্ট করা): ${NC})" DOMAIN
while [[ -z "$DOMAIN" ]]; do
    echo -e "${RED}ডোমেইন আবশ্যক!${NC}"
    read -p "$(echo -e ${YELLOW}👉 ডোমেইন লিখুন: ${NC})" DOMAIN
done

read -p "$(echo -e ${YELLOW}👉 আপনার ইমেইল (SSL এর জন্য): ${NC})" EMAIL

echo ""
echo -e "${GREEN}✅ তথ্য নেওয়া হয়েছে! ইনস্টলেশন শুরু হচ্ছে...${NC}"
echo ""

#===========================================
# 1. UPDATE SYSTEM
#===========================================
echo -e "${GREEN}[1/8] 📦 সিস্টেম আপডেট করা হচ্ছে...${NC}"
killall apt apt-get 2>/dev/null || true
rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock-frontend
dpkg --configure -a
apt update
apt install -y curl wget tar socat jq uuid-runtime openssl ufw nginx
echo -e "${GREEN}✅ সিস্টেম আপডেট সম্পন্ন!${NC}"

#===========================================
# 2. OPEN PORTS
#===========================================
echo -e "${GREEN}[2/8] 🔥 ফায়ারওয়াল কনফিগার করা হচ্ছে...${NC}"
ufw --force disable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow 8443/tcp comment 'VMess WS'
ufw allow 8080/tcp comment 'Trojan'
ufw allow 54321/tcp comment 'X-UI Panel'
echo "y" | ufw enable
echo -e "${GREEN}✅ ফায়ারওয়াল কনফিগার সম্পন্ন!${NC}"

#===========================================
# 3. INSTALL X-UI PANEL
#===========================================
echo -e "${GREEN}[3/8] 🎛️ X-UI প্যানেল ইনস্টল করা হচ্ছে...${NC}"

# Generate random credentials
XUI_PORT=54321
XUI_USER="emidev_$(openssl rand -hex 3)"
XUI_PASS=$(openssl rand -hex 12)
XUI_PATH="$(openssl rand -hex 8)"

# Install X-UI with auto answer
cd /root
wget -q -O /root/xui-install.sh https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh
chmod +x /root/xui-install.sh

# Auto install with config
cat > /root/xui-auto.conf <<EOF
n
n
y
${XUI_PORT}
${XUI_USER}
${XUI_PASS}
${XUI_PATH}
y
EOF

bash /root/xui-install.sh < /root/xui-auto.conf

# Wait for installation
sleep 5

echo -e "${GREEN}✅ X-UI প্যানেল ইনস্টল সম্পন্ন!${NC}"

#===========================================
# 4. GET SSL CERTIFICATE
#===========================================
echo -e "${GREEN}[4/8] 🔒 SSL সার্টিফিকেট নেওয়া হচ্ছে...${NC}"

# Stop nginx if running
systemctl stop nginx 2>/dev/null || true

# Install acme.sh
curl -s https://get.acme.sh | sh -s email=$EMAIL

# Issue certificate
~/.acme.sh/acme.sh --issue --standalone -d $DOMAIN --force

if [ -d ~/.acme.sh/${DOMAIN} ]; then
    mkdir -p /etc/ssl/emidev
    ~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
        --key-file /etc/ssl/emidev/private.key \
        --fullchain-file /etc/ssl/emidev/cert.crt
    echo -e "${GREEN}✅ SSL সার্টিফিকেট সফলভাবে নেওয়া হয়েছে!${NC}"
else
    echo -e "${RED}❌ SSL সার্টিফিকেট নিতে ব্যর্থ! HTTP মোডে চলবে${NC}"
fi

#===========================================
# 5. GENERATE REALITY KEYS
#===========================================
echo -e "${GREEN}[5/8] 🔑 Reality Keys জেনারেট করা হচ্ছে...${NC}"

cd /usr/local/x-ui/bin/
REALITY_KEYS=$(./xray-linux-amd64 x25519)
PRIVATE_KEY=$(echo "$REALITY_KEYS" | head -1 | awk '{print $3}')
PUBLIC_KEY=$(echo "$REALITY_KEYS" | tail -1 | awk '{print $3}')
SHORT_ID=$(openssl rand -hex 8)
UUID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)

echo -e "${GREEN}✅ Reality Keys জেনারেট সম্পন্ন!${NC}"

#===========================================
# 6. CREATE XRAY CONFIGURATION
#===========================================
echo -e "${GREEN}[6/8] 📝 Xray কনফিগারেশন তৈরি করা হচ্ছে...${NC}"

# Get the path to xray binary
XRAY_BIN=$(find /usr/local/x-ui -name "xray-linux-amd64" 2>/dev/null | head -1)

cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          { 
            "id": "$UUID",
            "flow": "xtls-rprx-vision",
            "email": "emidev@reality"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.microsoft.com:443",
          "xver": 0,
          "serverNames": ["$DOMAIN", "www.microsoft.com", "www.bing.com"],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": ["$SHORT_ID"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    },
    {
      "listen": "0.0.0.0",
      "port": 8443,
      "protocol": "vmess",
      "settings": {
        "clients": [
          { 
            "id": "$UUID",
            "alterId": 0,
            "email": "emidev@vmess"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "serverName": "$DOMAIN",
          "certificates": [
            {
              "certificateFile": "/etc/ssl/emidev/cert.crt",
              "keyFile": "/etc/ssl/emidev/private.key"
            }
          ]
        },
        "wsSettings": {
          "path": "/emidev",
          "headers": {
            "Host": "$DOMAIN"
          }
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "listen": "0.0.0.0",
      "port": 8080,
      "protocol": "trojan",
      "settings": {
        "clients": [
          { 
            "password": "$UUID",
            "email": "emidev@trojan"
          }
        ],
        "fallbacks": [
          {
            "dest": 80
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct",
      "settings": {
        "domainStrategy": "UseIP"
      }
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "domain": ["geosite:category-ads-all"],
        "outboundTag": "block"
      }
    ]
  }
}
EOF

echo -e "${GREEN}✅ Xray কনফিগারেশন তৈরি সম্পন্ন!${NC}"

#===========================================
# 7. ENABLE BBR
#===========================================
echo -e "${GREEN}[7/8] 🚀 BBR কনজেশন কন্ট্রোল সেটআপ করা হচ্ছে...${NC}"

if [[ $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}') != "bbr" ]]; then
    cat >> /etc/sysctl.conf <<EOF

# BBR Congestion Control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
    sysctl -p 2>/dev/null || true
fi

echo -e "${GREEN}✅ BBR সক্রিয় করা হয়েছে!${NC}"

#===========================================
# 8. RESTART SERVICES
#===========================================
echo -e "${GREEN}[8/8] 🔄 সার্ভিস রিস্টার্ট করা হচ্ছে...${NC}"

# Fix permissions
chmod 644 /usr/local/etc/xray/config.json
chmod 755 /usr/local/etc/xray
mkdir -p /var/log/xray
chown -R nobody:nogroup /var/log/xray

# Restart services
systemctl restart x-ui
systemctl enable x-ui
systemctl restart xray
systemctl enable xray

sleep 3

# Check if services are running
if systemctl is-active --quiet x-ui; then
    echo -e "${GREEN}✅ X-UI প্যানেল চালু আছে${NC}"
else
    echo -e "${RED}❌ X-UI প্যানেলে সমস্যা${NC}"
fi

if systemctl is-active --quiet xray; then
    echo -e "${GREEN}✅ Xray চালু আছে${NC}"
else
    echo -e "${RED}❌ Xray চালু করতে সমস্যা${NC}"
    # Try to fix Xray
    echo -e "${YELLOW}Xray ঠিক করার চেষ্টা করা হচ্ছে...${NC}"
    systemctl restart xray 2>/dev/null || true
    sleep 2
    if systemctl is-active --quiet xray; then
        echo -e "${GREEN}✅ Xray এখন চালু আছে${NC}"
    fi
fi

#===========================================
# SAVE INFORMATION
#===========================================
cat > /root/emidev_info.txt <<EOF
╔══════════════════════════════════════════════════════════════════════╗
║                    🔐 EMIDEV INSTALLATION INFO 🔐                     ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  📅 Install Date: $(date '+%Y-%m-%d %H:%M:%S')                       ║
║  🌐 Server IP: $SERVER_IP                                            ║
║  🔗 Domain: $DOMAIN                                                  ║
║  🔑 UUID: $UUID                                                      ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║                      🎛️ X-UI PANEL ACCESS                            ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  🌐 URL: http://$SERVER_IP:$XUI_PORT/$XUI_PATH/                      ║
║  👤 Username: $XUI_USER                                              ║
║  🔒 Password: $XUI_PASS                                              ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║                      🔐 SSL CERTIFICATE                              ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  📁 Certificate: /etc/ssl/emidev/cert.crt                           ║
║  📁 Private Key: /etc/ssl/emidev/private.key                        ║
║  🔄 Auto-renew: ~/.acme.sh/acme.sh --cron                           ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║                      📱 PROTOCOL CONFIGS                             ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  🔷 VLESS + REALITY (Port 443) - BEST SECURITY                       ║
║     Server: $DOMAIN                                                  ║
║     Port: 443                                                        ║
║     UUID: $UUID                                                      ║
║     Flow: xtls-rprx-vision                                           ║
║     Security: reality                                                ║
║     Public Key: $PUBLIC_KEY                                          ║
║     Short ID: $SHORT_ID                                              ║
║                                                                      ║
║  🔷 VMESS + WS + TLS (Port 8443) - CDN READY                         ║
║     Server: $DOMAIN                                                  ║
║     Port: 8443                                                       ║
║     UUID: $UUID                                                      ║
║     Path: /emidev                                                    ║
║     TLS: ON with SSL                                                 ║
║                                                                      ║
║  🔷 TROJAN (Port 8080) - LEGACY                                      ║
║     Server: $SERVER_IP                                               ║
║     Port: 8080                                                       ║
║     Password: $UUID                                                  ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║                      🔧 QUICK LINKS                                  ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  📋 Reality VLESS Link (copy this):                                  ║
║  vless://$UUID@$DOMAIN:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$DOMAIN&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp&headerType=none#$DOMAIN-REALITY
║                                                                      ║
║  📱 VMess Config (for V2RayNG/Nekobox):                              ║
║  vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$DOMAIN-VMESS\",\"add\":\"$DOMAIN\",\"port\":\"8443\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$DOMAIN\",\"path\":\"/emidev\",\"tls\":\"tls\"}" | base64 -w 0)
║                                                                      ║
║  🔰 Trojan Link:                                                     ║
║  trojan://$UUID@$DOMAIN:8080#$DOMAIN-TROJAN                          ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║                      🔧 COMMANDS                                     ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  Show Info:     cat /root/emidev_info.txt                           ║
║  X-UI Status:   systemctl status x-ui                               ║
║  Xray Status:   systemctl status xray                               ║
║  Renew SSL:     ~/.acme.sh/acme.sh --renew -d $DOMAIN               ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF

#===========================================
# SHOW FINAL MESSAGE
#===========================================
clear

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║              🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉       ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}                    📋 IMPORTANT INFORMATION${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${GREEN}  🎛️ X-UI PANEL:${NC}"
echo -e "     http://$SERVER_IP:54321/$XUI_PATH/"
echo ""
echo -e "${GREEN}  👤 Username:${NC} $XUI_USER"
echo -e "${GREEN}  🔒 Password:${NC} $XUI_PASS"
echo ""
echo -e "${GREEN}  📁 All Info Saved:${NC} cat /root/emidev_info.txt"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}                    📱 READY TO USE${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${GREEN}  ✅ VLESS + Reality (Port 443) - BEST${NC}"
echo -e "${GREEN}  ✅ VMess + WebSocket + TLS (Port 8443)${NC}"
echo -e "${GREEN}  ✅ Trojan (Port 8080)${NC}"
echo -e "${GREEN}  ✅ SSL Certificate Installed${NC}"
echo -e "${GREEN}  ✅ X-UI Panel Ready${NC}"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  ❤️  ধন্যবাদ emidev ব্যবহার করার জন্য!${NC}"
echo -e "${BLUE}  🔗 GitHub: https://github.com/manbdboy5-dot/emidev${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
