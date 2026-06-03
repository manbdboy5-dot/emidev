#!/bin/bash

# emidev - Multi-Protocol V2Ray/Xray Installer
# সর্বশেষ আপডেট: 2026

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ এই স্ক্রিপ্ট চালানোর জন্য আপনাকে root ইউজার হতে হবে (sudo ব্যবহার করুন)।${NC}" 
   exit 1
fi

# Banner
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       ${GREEN}emidev Multi-Protocol Installer${BLUE}       ║${NC}"
echo -e "${BLUE}║         ${YELLOW}V2Ray/Xray - VMess + VLESS + Trojan${BLUE}     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Function to install Xray-core
install_xray() {
    echo -e "${GREEN}📦 Xray-core ইনস্টল করা হচ্ছে...${NC}"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    echo -e "${GREEN}✅ Xray-core ইনস্টল সম্পন্ন!${NC}"
}

# Function to generate configuration
gen_config() {
    echo -e "${GREEN}⚙️  কনফিগারেশন জেনারেট করা হচ্ছে...${NC}"
    mkdir -p /etc/emidev
    
    # Get server IP
    SERVER_IP=$(curl -s https://api.ipify.org)
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(curl -s ipv4.icanhazip.com)
    fi
    
    echo ""
    echo -e "${YELLOW}🔧 কিছু তথ্য দিন:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # User Inputs
    read -p "👉 আপনার ডোমেইন/সাবডোমেইন লিখুন (যেটা এই IP: $SERVER_IP এ পয়েন্ট করা আছে): " DOMAIN
    while [[ -z "$DOMAIN" ]]; do
        echo -e "${RED}ডোমেইন আবশ্যক!${NC}"
        read -p "👉 আপনার ডোমেইন/সাবডোমেইন লিখুন: " DOMAIN
    done
    
    read -p "👉 REALITY এর জন্য ক্যামোফ্লাজ সাইট [www.microsoft.com]: " FALLBACK_SITE
    FALLBACK_SITE=${FALLBACK_SITE:-www.microsoft.com}
    
    read -p "👉 WebSocket পাথ লিখুন [emidev]: " WSPATH
    WSPATH=${WSPATH:-emidev}
    
    echo ""
    echo -e "${YELLOW}🔑 কী জেনারেট করা হচ্ছে (একটু অপেক্ষা করুন)...${NC}"
    
    # Generate UUID
    UUID=$(cat /proc/sys/kernel/random/uuid)
    
    # Generate Reality Keys
    REALITY_KEYS=$(/usr/local/bin/xray x25519)
    PRIVATE_KEY=$(echo "$REALITY_KEYS" | head -1 | awk '{print $3}')
    PUBLIC_KEY=$(echo "$REALITY_KEYS" | tail -1 | awk '{print $3}')
    SHORT_ID=$(openssl rand -hex 8)
    
    # Generate flow
    FLOW="xtls-rprx-vision"
    
    # Create config.json
    echo -e "${GREEN}📝 কনফিগ ফাইল তৈরি হচ্ছে...${NC}"
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
            "flow": "$FLOW",
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
          "dest": "$FALLBACK_SITE:443",
          "xver": 0,
          "serverNames": ["$DOMAIN", "$FALLBACK_SITE"],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": ["$SHORT_ID"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": false
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
          "alpn": ["http/1.1", "h2"],
          "minVersion": "1.2"
        },
        "wsSettings": { 
          "path": "/$WSPATH",
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
      "tag": "block",
      "settings": {}
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

    # Create client information file
    cat > /root/emidev_info.txt <<EOF
╔══════════════════════════════════════════════════════════════╗
║           🔐 emidev Configuration Information 🔐             ║
╚══════════════════════════════════════════════════════════════╝

📅 Created: $(date)
🌐 Server IP: $SERVER_IP
🔗 Domain: $DOMAIN

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔷 PROTOCOL 1: VLESS + REALITY (Recommended - Best Anti-Detection)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Address (সার্ভার): $DOMAIN  or  $SERVER_IP
Port: 443
UUID: $UUID
Flow: $FLOW
Security: reality
Public Key: $PUBLIC_KEY
Short ID: $SHORT_ID
Server Name (SNI): $DOMAIN
Fingerprint: chrome

📱 Reality Config (Copy this for Sing-box/Shadowrocket/Nekobox):
vless://$UUID@$DOMAIN:443?encryption=none&flow=$FLOW&security=reality&sni=$DOMAIN&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp&headerType=none#$DOMAIN-REALITY

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔷 PROTOCOL 2: VMess + WebSocket + TLS (CDN Compatible)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Address: $DOMAIN
Port: 8443
UUID: $UUID
Alter ID: 0
Security: auto
Network: ws
Path: /$WSPATH
TLS: ON
SNI: $DOMAIN

📱 VMess Config (Copy this for V2Ray clients):
vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$DOMAIN-VMESS\",\"add\":\"$DOMAIN\",\"port\":\"8443\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$DOMAIN\",\"path\":\"/$WSPATH\",\"tls\":\"tls\"}" | base64 -w 0)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔷 PROTOCOL 3: Trojan (Legacy Support)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Address: $SERVER_IP  or  $DOMAIN
Port: 8080
Password: $UUID
Network: tcp
Security: none

📱 Trojan Config:
trojan://$UUID@$SERVER_IP:8080#$DOMAIN-TROJAN

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  IMPORTANT NOTES:
• সব কানেকশন একই সাথে কাজ করবে
• Reality প্রোটোকল সবচেয়ে সুরক্ষিত (CDN ছাড়া ব্যবহার করুন)
• VMess + TLS CDN এর মাধ্যমে ব্যবহার করতে পারেন
• কনফিগারেশন ফাইল লোকেশন: /usr/local/etc/xray/config.json

🔧 Management Commands:
• Restart Xray: systemctl restart xray
• Check Status: systemctl status xray
• View Logs: journalctl -u xray -f
• Show Info: cat /root/emidev_info.txt

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

    echo ""
    echo -e "${GREEN}✅ কনফিগারেশন সফলভাবে তৈরি হয়েছে!${NC}"
    echo -e "${YELLOW}📄 সব তথ্য এই ফাইলে সেভ করা আছে: /root/emidev_info.txt${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    cat /root/emidev_info.txt
}

# Function to setup firewall
setup_firewall() {
    echo -e "${GREEN}🔥 ফায়ারওয়াল কনফিগার করা হচ্ছে...${NC}"
    
    # Check if ufw is installed
    if ! command -v ufw &> /dev/null; then
        apt update
        apt install ufw -y
    fi
    
    # Configure UFW
    ufw --force disable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp comment 'SSH'
    ufw allow 443/tcp comment 'VLESS Reality'
    ufw allow 8443/tcp comment 'VMess WebSocket'
    ufw allow 8080/tcp comment 'Trojan'
    ufw --force enable
    
    echo -e "${GREEN}✅ ফায়ারওয়াল কনফিগার সম্পন্ন!${NC}"
}

# Function to setup BBR (Better performance)
setup_bbr() {
    echo -e "${GREEN}🚀 BBR কনজেশন কন্ট্রোল সেটআপ করা হচ্ছে...${NC}"
    
    # Check if BBR is already enabled
    if [[ $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}') == "bbr" ]]; then
        echo -e "${GREEN}✅ BBR ইতিমধ্যে সক্রিয়!${NC}"
        return
    fi
    
    # Enable BBR
    cat >> /etc/sysctl.conf <<EOF
# BBR Congestion Control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
    
    sysctl -p
    echo -e "${GREEN}✅ BBR সক্রিয় করা হয়েছে!${NC}"
}

# Function to restart services
restart_services() {
    echo -e "${GREEN}🔄 Xray সার্ভিস রিস্টার্ট করা হচ্ছে...${NC}"
    systemctl restart xray
    systemctl enable xray
    
    # Check if Xray is running
    if systemctl is-active --quiet xray; then
        echo -e "${GREEN}✅ Xray সফলভাবে চালু হয়েছে!${NC}"
    else
        echo -e "${RED}❌ Xray চালু করতে সমস্যা হয়েছে!${NC}"
        echo -e "${YELLOW}লগ চেক করুন: journalctl -u xray -f${NC}"
        exit 1
    fi
}

# Main execution
main() {
    install_xray
    sleep 2
    gen_config
    setup_firewall
    setup_bbr
    restart_services
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     🎉 ইনস্টলেশন সম্পূর্ণ হয়েছে! 🎉     ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}📋 আপনার কনফিগারেশন সংরক্ষিত হয়েছে:${NC}"
    echo -e "${BLUE}   cat /root/emidev_info.txt${NC}"
    echo ""
    echo -e "${YELLOW}🔧 Xray ম্যানেজমেন্ট:${NC}"
    echo -e "${BLUE}   systemctl restart xray${NC} - রিস্টার্ট"
    echo -e "${BLUE}   systemctl status xray${NC}  - স্ট্যাটাস"
    echo -e "${BLUE}   systemctl stop xray${NC}     - স্টপ"
    echo -e "${BLUE}   systemctl start xray${NC}    - স্টার্ট"
    echo ""
}

# Run main function
main
