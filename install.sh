#!/bin/bash

# emidev - X-UI Panel + Multi-Protocol V2Ray/Xray Installer
# সর্বশেষ আপডেট: 2026

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ এই স্ক্রিপ্ট চালানোর জন্য আপনাকে root ইউজার হতে হবে (sudo ব্যবহার করুন)।${NC}" 
   exit 1
fi

# Banner
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     ${GREEN}emidev - X-UI Panel + Multi-Protocol Installer${BLUE}     ║${NC}"
echo -e "${BLUE}║              ${YELLOW}VMess + VLESS + Reality + Trojan${BLUE}              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to update system
update_system() {
    echo -e "${GREEN}📦 সিস্টেম আপডেট করা হচ্ছে...${NC}"
    # Kill any running apt processes
    sudo killall apt apt-get 2>/dev/null || true
    sleep 2
    # Remove locks
    sudo rm -f /var/lib/apt/lists/lock
    sudo rm -f /var/cache/apt/archives/lock
    sudo rm -f /var/lib/dpkg/lock-frontend
    sudo dpkg --configure -a
    apt update
    apt install -y curl wget tar socat jq uuid-runtime openssl
    echo -e "${GREEN}✅ সিস্টেম আপডেট সম্পন্ন!${NC}"
}

# Function to install X-UI Panel
install_xui() {
    echo -e "${GREEN}🎛️ X-UI প্যানেল ইনস্টল করা হচ্ছে...${NC}"
    
    # Install X-UI (Alireza0 version - best for Reality)
    cd /root/
    wget -O /root/xui-install.sh https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh
    chmod +x /root/xui-install.sh
    
    # Auto install with default settings
    bash /root/xui-install.sh <<EOF
1
1
1
1
EOF
    
    # Wait for installation to complete
    sleep 5
    
    # Get X-UI credentials
    if [ -f /usr/local/x-ui/x-ui.db ]; then
        # Default credentials after fresh install
        XUI_USERNAME="admin"
        XUI_PASSWORD="admin"
    fi
    
    echo -e "${GREEN}✅ X-UI প্যানেল ইনস্টল সম্পন্ন!${NC}"
}

# Function to configure X-UI
configure_xui() {
    echo -e "${GREEN}⚙️ X-UI কনফিগার করা হচ্ছে...${NC}"
    
    # Get server IP
    SERVER_IP=$(curl -s https://api.ipify.org)
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(curl -s ipv4.icanhazip.com)
    fi
    
    # User inputs
    echo ""
    echo -e "${YELLOW}🔧 X-UI সেটআপ করার জন্য কিছু তথ্য দিন:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "👉 X-UI প্যানেলের পোর্ট (ডিফল্ট: 54321): " XUI_PORT
    XUI_PORT=${XUI_PORT:-54321}
    
    read -p "👉 X-UI এর ইউজারনেম (ডিফল্ট: emidev): " XUI_USER
    XUI_USER=${XUI_USER:-emidev}
    
    read -p "👉 X-UI এর পাসওয়ার্ড (ডিফল্ট: random): " XUI_PASS
    if [[ -z "$XUI_PASS" ]]; then
        XUI_PASS=$(openssl rand -hex 8)
    fi
    
    read -p "👉 আপনার ডোমেইন (যেটা এই IP: $SERVER_IP এ পয়েন্ট করা আছে): " DOMAIN
    while [[ -z "$DOMAIN" ]]; do
        echo -e "${RED}ডোমেইন আবশ্যক!${NC}"
        read -p "👉 আপনার ডোমেইন: " DOMAIN
    done
    
    # Update X-UI config
    cat > /usr/local/x-ui/x-ui.config.json <<EOF
{
    "web": {
        "port": $XUI_PORT,
        "secret": "",
        "basePath": "/",
        "username": "$XUI_USER",
        "password": "$XUI_PASS"
    },
    "log": {
        "level": "info"
    },
    "xray": {
        "config": "/usr/local/x-ui/bin/config.json",
        "binary": "/usr/local/x-ui/bin/xray-linux-amd64"
    }
}
EOF
    
    # Create default inbound configs via X-UI API
    # Wait for X-UI to start
    systemctl restart x-ui
    
    sleep 5
    
    # Generate UUID
    UUID=$(cat /proc/sys/kernel/random/uuid)
    
    # Login to X-UI and setup inbounds
    echo -e "${YELLOW}📡 ইনবাউন্ড সেটআপ করা হচ্ছে...${NC}"
    
    # Simple config file as backup
    cat > /usr/local/x-ui/bin/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "$UUID", "flow": "xtls-rprx-vision" }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "www.microsoft.com:443",
          "serverNames": ["$DOMAIN", "www.microsoft.com"],
          "privateKey": "$(cat /usr/local/x-ui/bin/xray-linux-amd64 x25519 | head -1 | awk '{print $3}')",
          "shortIds": ["$(openssl rand -hex 8)"]
        }
      }
    },
    {
      "listen": "0.0.0.0",
      "port": 8443,
      "protocol": "vmess",
      "settings": {
        "clients": [{ "id": "$UUID", "alterId": 0 }]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": { "serverName": "$DOMAIN" },
        "wsSettings": { "path": "/emidev" }
      }
    },
    {
      "listen": "0.0.0.0",
      "port": 8080,
      "protocol": "trojan",
      "settings": { "clients": [{ "password": "$UUID" }] }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF
    
    # Save info
    cat > /root/emidev_info.txt <<EOF
╔══════════════════════════════════════════════════════════════╗
║           🔐 emidev - X-UI Panel Information 🔐              ║
╚══════════════════════════════════════════════════════════════╝

🌐 Server IP: $SERVER_IP
🔗 Domain: $DOMAIN

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎛️ X-UI PANEL ACCESS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
URL: http://$SERVER_IP:$XUI_PORT
Username: $XUI_USER
Password: $XUI_PASS

⚠️ প্যানেল লগইন করার পর:
1. ইনবাউন্ডস এ গিয়ে নতুন ইউজার যোগ করুন
2. আপনার পছন্দমত সেটিংস কনফিগার করুন
3. ক্লায়েন্ট কনফিগ কপি করে ব্যবহার করুন

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📱 QUICK CONFIG (Backup - Auto Created):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
VLESS Reality:
  Address: $DOMAIN
  Port: 443
  UUID: $UUID

VMess + TLS:
  Address: $DOMAIN
  Port: 8443
  UUID: $UUID
  Path: /emidev

Trojan:
  Address: $SERVER_IP
  Port: 8080
  Password: $UUID

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 Management Commands:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
X-UI Panel: systemctl restart x-ui
Xray Core: systemctl restart xray
Show Info: cat /root/emidev_info.txt
X-UI Logs: journalctl -u x-ui -f
Xray Logs: journalctl -u xray -f

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

    echo ""
    echo -e "${GREEN}✅ X-UI কনফিগার সম্পন্ন!${NC}"
}

# Function to setup firewall
setup_firewall() {
    echo -e "${GREEN}🔥 ফায়ারওয়াল কনফিগার করা হচ্ছে...${NC}"
    
    if ! command -v ufw &> /dev/null; then
        apt update
        apt install ufw -y
    fi
    
    ufw --force disable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp comment 'SSH'
    ufw allow 443/tcp comment 'VLESS Reality'
    ufw allow 8443/tcp comment 'VMess WebSocket'
    ufw allow 8080/tcp comment 'Trojan'
    ufw allow "$XUI_PORT"/tcp comment 'X-UI Panel'
    ufw --force enable
    
    echo -e "${GREEN}✅ ফায়ারওয়াল কনফিগার সম্পন্ন!${NC}"
}

# Function to enable BBR
setup_bbr() {
    echo -e "${GREEN}🚀 BBR কনজেশন কন্ট্রোল সেটআপ করা হচ্ছে...${NC}"
    
    if [[ $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}') != "bbr" ]]; then
        cat >> /etc/sysctl.conf <<EOF
# BBR Congestion Control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
        sysctl -p
        echo -e "${GREEN}✅ BBR সক্রিয় করা হয়েছে!${NC}"
    else
        echo -e "${GREEN}✅ BBR ইতিমধ্যে সক্রিয়!${NC}"
    fi
}

# Function to restart services
restart_services() {
    echo -e "${GREEN}🔄 সার্ভিস রিস্টার্ট করা হচ্ছে...${NC}"
    
    systemctl restart x-ui
    systemctl enable x-ui
    systemctl restart xray
    systemctl enable xray
    
    sleep 3
    
    if systemctl is-active --quiet x-ui; then
        echo -e "${GREEN}✅ X-UI প্যানেল সফলভাবে চালু হয়েছে!${NC}"
    else
        echo -e "${RED}❌ X-UI চালুতে সমস্যা!${NC}"
    fi
    
    if systemctl is-active --quiet xray; then
        echo -e "${GREEN}✅ Xray সফলভাবে চালু হয়েছে!${NC}"
    else
        echo -e "${RED}❌ Xray চালুতে সমস্যা!${NC}"
    fi
}

# Main execution
main() {
    update_system
    install_xui
    configure_xui
    setup_firewall
    setup_bbr
    restart_services
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     🎉 emidev - X-UI Panel ইনস্টলেশন সম্পূর্ণ! 🎉        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Display info
    cat /root/emidev_info.txt
    
    echo ""
    echo -e "${YELLOW}💡 গুরুত্বপূর্ণ টিপস:${NC}"
    echo -e "${CYAN}• X-UI প্যানেল খুলে ইনবাউন্ড কাস্টমাইজ করুন${NC}"
    echo -e "${CYAN}• Reality এর জন্য Public Key প্যানেলে দেখাবে${NC}"
    echo -e "${CYAN}• ক্লায়েন্ট কনফিগ প্যানেল থেকে কপি করুন${NC}"
    echo ""
    echo -e "${BLUE}📋 সব তথ্য সংরক্ষিত: ${YELLOW}cat /root/emidev_info.txt${NC}"
}

# Run main
main
