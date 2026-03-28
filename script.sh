#!/bin/bash

set -e

echo "🚀 Starting Ubuntu Hardening..."

echo "============================================================"
echo "🔐 Ubuntu Hardening & Bootstrap Script"
echo "============================================================"
echo ""
echo "PURPOSE:"
echo "  Automates baseline security hardening for Ubuntu VPS"
echo ""
echo "THIS SCRIPT WILL:"
echo "  • Create a non-root sudo user"
echo "  • Disable root & password-based SSH login"
echo "  • Configure firewall (deny-by-default)"
echo "  • Enable Fail2Ban (anti-brute-force)"
echo "  • Install Docker (non-root ready)"
echo "  • Apply kernel-level protections"
echo ""
echo "INPUT REQUIRED:"
echo "  • Username"
echo "  • Password (for sudo only)"
echo "  • SSH Port"
echo ""
echo "⚠️ IMPORTANT:"
echo "  • SSH password login will be DISABLED"
echo "  • You MUST configure SSH key access"
echo "  • Test login before closing this session"
echo ""
echo "============================================================"
echo ""
sleep 2

#############################
# 1. DEFAULTS
#############################

DEFAULT_USER="test"
DEFAULT_PASSWORD="test"
DEFAULT_SSH_PORT=2222

#############################
# 2. INTERACTIVE INPUT
#############################

echo "🔧 Configuration Setup (Press Enter to use defaults)"

read -p "Enter username [default: $DEFAULT_USER]: " NEW_USER
NEW_USER=${NEW_USER:-$DEFAULT_USER}

read -p "Enter password [default: $DEFAULT_PASSWORD]: " NEW_PASSWORD
NEW_PASSWORD=${NEW_PASSWORD:-$DEFAULT_PASSWORD}

read -p "Enter SSH port [default: $DEFAULT_SSH_PORT]: " SSH_PORT
SSH_PORT=${SSH_PORT:-$DEFAULT_SSH_PORT}

#############################
# 3. VALIDATION
#############################

if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
    echo "❌ Invalid SSH port"
    exit 1
fi

#############################
# 4. PRE-CHECKS
#############################

if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root"
  exit 1
fi

#############################
# 5. UPDATE SYSTEM
#############################

echo "📦 Updating system..."
apt update && apt upgrade -y

#############################
# 6. CREATE USER
#############################

if id "$NEW_USER" &>/dev/null; then
    echo "👤 User $NEW_USER already exists"
else
    echo "👤 Creating user $NEW_USER"
    adduser --disabled-password --gecos "" $NEW_USER
    echo "$NEW_USER:$NEW_PASSWORD" | chpasswd
    usermod -aG sudo $NEW_USER
fi

#############################
# 7. SSH HARDENING
#############################

echo "🔐 Hardening SSH..."

SSH_CONFIG="/etc/ssh/sshd_config"

cp $SSH_CONFIG ${SSH_CONFIG}.bak

sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin no/" $SSH_CONFIG
sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" $SSH_CONFIG
sed -i "s/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/" $SSH_CONFIG

if grep -q "^Port" $SSH_CONFIG; then
    sed -i "s/^Port.*/Port $SSH_PORT/" $SSH_CONFIG
else
    echo "Port $SSH_PORT" >> $SSH_CONFIG
fi

systemctl restart ssh

#############################
# 8. FIREWALL (UFW)
#############################

echo "🔥 Configuring firewall..."

apt install ufw -y

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

ufw allow $SSH_PORT/tcp
ufw allow 80/tcp
ufw allow 443/tcp

ufw --force enable

#############################
# 9. FAIL2BAN
#############################

echo "🛡️ Installing Fail2Ban..."

apt install fail2ban -y

cat <<EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = $SSH_PORT
maxretry = 5
bantime = 3600
findtime = 600
EOF

systemctl enable fail2ban
systemctl restart fail2ban

#############################
# 10. UTILITIES
#############################

echo "🧰 Installing utilities..."

apt install -y htop iotop nethogs curl git unzip ca-certificates gnupg lsb-release

#############################
# 11. DOCKER INSTALL
#############################

echo "🐳 Installing Docker..."

apt remove -y docker docker-engine docker.io containerd runc || true

mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt update

apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

usermod -aG docker $NEW_USER

systemctl enable docker
systemctl start docker

#############################
# 12. SYSCTL HARDENING
#############################

echo "⚙️ Applying kernel hardening..."

cat <<EOF >> /etc/sysctl.conf

net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.tcp_syncookies=1

EOF

sysctl -p

#############################
# 13. DISABLE UNUSED SERVICES
#############################

echo "🚫 Disabling unnecessary services..."

systemctl disable avahi-daemon || true

#############################
# 14. CLEANUP
#############################

echo "🧹 Cleaning up..."

apt autoremove -y
apt clean

#############################
# 15. FINAL OUTPUT
#############################

echo ""
echo "✅ Hardening Complete!"
echo ""
echo "🔑 Access Details:"
echo "User: $NEW_USER"
echo "Password: $NEW_PASSWORD"
echo "SSH Port: $SSH_PORT"
echo ""
echo "⚠️ IMPORTANT:"
echo "- Password SSH login is DISABLED"
echo "- Use SSH key authentication"
echo ""
echo "👉 Next:"
echo "ssh-copy-id -p $SSH_PORT $NEW_USER@SERVER_IP"
echo ""
echo "👉 Test before exit:"
echo "ssh -p $SSH_PORT $NEW_USER@SERVER_IP"
