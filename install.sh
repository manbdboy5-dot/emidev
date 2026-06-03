#!/bin/bash

# emidev - X-UI Panel + Multi-Protocol V2Ray/Xray Installer
# কপিরাইট: manbdboy5-dot/emidev

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ এই স্ক্রিপ্ট চালানোর জন্য root ইউজার হতে হবে!${NC}" 
   echo -e "${YELLOW}👉 ব্যবহার করুন: sudo bash install.sh${NC}"
   exit 1
fi

# Clear screen
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
echo -e "${BLUE}║        ${YELLOW}X-UI Panel + Multi-Protocol Installer${BLUE}               ║${NC}"
echo -e "${BLUE}║                    ${CYAN}by manbdboy5-dot${BLUE}                           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
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
    
    # Fix dpkg
    sudo dpkg --configure -a 2>/dev/null || true
    
    # Update system
    apt update
    apt install -y curl wget tar socat jq uuid-runtime openssl ufw systemd
    
    echo -e "${GREEN}✅ সিস্টেম আপডেট সম্পন্ন!${NC}"
}

# Function to install X-UI
install_xui() {
    echo -e "${GREEN}🎛️ X-UI প্যানেল ইনস্টল করা হচ্ছে...${NC}"
    echo ""
    
    # Download X-UI install script
    wget -q -O /tmp/xui-install.sh https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh
    
    if [ ! -f /tmp/xui-install.sh ]; then
        echo -e "${RED}❌ ডাউনলোড ব্যর্থ! চেক করুন ইন্টারনেট সংযোগ${NC}"
        exit 1
    fi
    
    chmod +x /tmp/xui-install.sh
    
    # Set variables for auto-install
    export XUI_PORT="54321"
    export XUI_USERNAME="emidev"
    export XUI_PASSWORD="EmiDev@2026"
    
    # Run X-UI installation
    bash /tmp/xui-install.sh
    
    echo -e "${GREEN}✅ X-UI প্যানেল ইনস্টল সম্পন্ন!${NC}"
}

# Function to get server info
get_server_info() {
    echo ""
    echo -e "${YELLOW}🔧 সার্ভার তথ্য সংগ্রহ করা হচ্ছে...${NC}"
    
    # Get server IP
    SERVER_IP=$(curl -s -4 https://api.ipify.org 2>/dev/null)
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(curl -s -4 ipv4.icanhazip.com 2>/dev/null)
    fi
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
    fi
    
    echo -e "${CYAN}🌐 সার্ভার IP: ${GREEN}$SERVER_IP${NC}"
    echo ""
    
    # Get domain
    read -p "$(echo -e ${YELLOW}👉 আপনার ডোমেইন লিখুন (যেটা $SERVER_IP এ পয়েন্ট করা): ${NC})" DOMAIN
    
    while [[ -z "$DOMAIN" ]]; do
        echo -e "${RED}❌ ডোমেইন আবশ্যক!${NC}"
        read -p "$(echo -e ${YELLOW}👉 ডোমেইন লিখুন: ${NC})" DOMAIN
    done
    
    # Generate UUID
    UUID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)
    
    echo -e "${GREEN}✅ ডোমেইন সেভ করা হয়েছে: $DOMAIN${NC}"
}

# Function to configure firewall
setup_firewall() {
    echo -e "${GREEN}🔥 ফায়ারওয়াল কনফিগার করা হচ্ছে...${NC}"
    
    # Reset UFW
    ufw --force disable
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow ports
    ufw allow 22/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS/VLESS Reality'
    ufw allow 8443/tcp comment 'VMess WebSocket'
    ufw allow 8080/tcp comment 'Trojan'
    ufw allow 54321/tcp comment 'X-UI Panel'
    
    # Enable UFW
    echo "y" | ufw enable
    
    echo -e "${GREEN}✅ ফায়ারওয়াল কনফিগার সম্পন্ন!${NC}"
}

# Function to enable BBR
setup_bbr() {
    echo -e "${GREEN}🚀 BBR কনজেশন কন্ট্রোল সেটআপ করা হচ্ছে...${NC}"
    
    # Check if BBR is already enabled
    if [[ $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}') == "bbr" ]]; then
        echo -e "${GREEN}✅ BBR ইতিমধ্যে সক্রিয়!${NC}"
        return
    fi
    
    # Enable BBR
    cat >> /etc/sysctl.conf <<EOF

# BBR Congestion Control for better speed
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
    
    sysctl -p 2>/dev/null || true
    
    echo -e "${GREEN}✅ BBR সক্রিয় করা হয়েছে!${NC}"
}

# Function to create backup config
create_backup_config() {
    echo -e "${GREEN}📝 ব্যাকআপ কনফিগ তৈরি করা হচ্ছে...${NC}"
    
    # Create config directory
    mkdir -p /etc/emidev
    
    # Create backup config.json
    cat > /etc/emidev/config.json <<EOF
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
          { 
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "www.microsoft.com:443",
          "serverNames": ["$DOMAIN", "www.microsoft.com", "www.bing.com"],
          "privateKey": "YOUR_PRIVATE_KEY",
          "publicKey": "YOUR_PUBLIC_KEY",
          "shortIds": ["$(openssl rand -hex 8)"]
        }
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
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": { 
          "serverName": "$DOMAIN"
        },
        "wsSettings": { 
          "path": "/emidev"
        }
      }
    },
    {
      "listen": "0.0.0.0",
      "port": 8080,
      "protocol": "trojan",
      "settings": { 
        "clients": [
          { 
            "password": "$UUID"
          }
        ]
      }
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
    
    echo -e "${GREEN}✅ ব্যাকআপ কনফিগ তৈরি হয়েছে: /etc/emidev/config.json${NC}"
}

# Function to save installation info
save_info() {
    cat > /root/emidev_info.txt <<EOF
╔══════════════════════════════════════════════════════════════════════╗
║                    🔐 emidev INSTALLATION INFO 🔐                     ║
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
║  🌐 URL: http://$SERVER_IP:54321                                     ║
║  👤 Username: emidev                                                 ║
║  🔒 Password: EmiDev@2026                                            ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║                      📱 PROTOCOL CONFIGS                              ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  🔷 VLESS + REALITY (Port 443)                                       ║
║     Server: $DOMAIN                                                  ║
║     Port: 443                                                        ║
║     UUID: $UUID                                                      ║
║     Flow: xtls-rprx-vision                                           ║
║                                                                      ║
║  🔷 VMess + WS + TLS (Port 8443)                                     ║
║     Server: $DOMAIN                                                  ║
║     Port: 8443                                                       ║
║     UUID: $UUID                                                      ║
║     Path: /emidev                                                    ║
║                                                                      ║
║  🔷 TROJAN (Port 8080)                                               ║
║     Server: $SERVER_IP                                               ║
║     Port: 8080                                                       ║
║     Password: $UUID                                                  ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║                      🔧 MANAGE COMMANDS                               ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  X-UI Panel:  systemctl status x-ui                                  ║
║  X-UI Restart: systemctl restart x-ui                                ║
║  Xray Status:  systemctl status xray                                 ║
║  Show Info:    cat /root/emidev_info.txt                             ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF

    echo -e "${GREEN}✅ ইনফরমেশন সেভ করা হয়েছে: /root/emidev_info.txt${NC}"
}

# Function to restart services
restart_services() {
    echo -e "${GREEN}🔄 সার্ভিস রিস্টার্ট করা হচ্ছে...${NC}"
    
    # Restart X-UI
    systemctl restart x-ui 2>/dev/null || true
    systemctl enable x-ui 2>/dev/null || true
    
    # Restart Xray if exists
    if systemctl list-unit-files | grep -q xray; then
        systemctl restart xray 2>/dev/null || true
    fi
    
    sleep 2
    
    echo -e "${GREEN}✅ সার্ভিস রিস্টার্ট সম্পন্ন!${NC}"
}

# Function to show final message
show_final() {
    clear
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}║              🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉       ║${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}                    🎛️ X-UI PANEL ACCESS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}  🌐 URL:${NC}      http://$SERVER_IP:54321"
    echo -e "${GREEN}  👤 Username:${NC} emidev"
    echo -e "${GREEN}  🔒 Password:${NC} EmiDev@2026"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}                    📋 NEXT STEPS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}  1.${NC} ব্রাউজারে উপরের URL এ যান"
    echo -e "${GREEN}  2.${NC} X-UI প্যানেলে লগইন করুন"
    echo -e "${GREEN}  3.${NC} 'Inbounds' মেনুতে গিয়ে নতুন কনফিগ তৈরি করুন"
    echo -e "${GREEN}  4.${NC} '+ Add Inbound' বাটনে ক্লিক করে প্রোটোকল যোগ করুন"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}                    💾 SAVED INFORMATION${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}  সব তথ্য সেভ করা হয়েছে:${NC}"
    echo -e "  cat /root/emidev_info.txt"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}  ❤️  ধন্যবাদ emidev ব্যবহার করার জন্য!${NC}"
    echo -e "${BLUE}  🔗 GitHub: https://github.com/manbdboy5-dot/emidev${NC}"
    echo ""
}

# Main execution
main() {
    update_system
    install_xui
    get_server_info
    setup_firewall
    setup_bbr
    create_backup_config
    save_info
    restart_services
    show_final
}

# Run main
main
