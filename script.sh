#!/bin/bash

set -e

echo "============================================================"
echo "🔐 Ubuntu Hardening & Bootstrap Script (Safe Edition)"
echo "============================================================"
echo ""

#############################
# 1. DEFAULTS
#############################

DEFAULT_USER="test"
DEFAULT_PASSWORD="test"
DEFAULT_SSH_PORT=2222

#############################
# 2. INPUT
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

if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root"
  exit 1
fi

#############################
# 4. UPDATE SYSTEM
#############################

echo "📦 Updating system..."
apt update && apt upgrade -y

#############################
# 5. CREATE USER
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
# 6. SSH CONFIG (SAFE)
#############################

echo "🔐 Configuring SSH safely..."

SSH_CONFIG="/etc/ssh/sshd_config"

# Backup
cp $SSH_CONFIG ${SSH_CONFIG}.bak

# Remove override configs (CRITICAL)
rm -f /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true

# Remove all existing Port entries
sed -i '/^Port/d' $SSH_CONFIG

# Remove conflicting auth lines
sed -i '/^PasswordAuthentication/d' $SSH_CONFIG
sed -i '/^PermitRootLogin/d' $SSH_CONFIG
sed -i '/^PubkeyAuthentication/d' $SSH_CONFIG

# Apply clean config
cat <<EOF >> $SSH_CONFIG

# --- Custom SSH Config ---
Port $SSH_PORT
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
EOF

# Restart SSH
systemctl restart ssh
sleep 2

# Validate SSH port
if ! ss -tulnp | grep -q ":$SSH_PORT"; then
  echo "❌ ERROR: SSH not listening on port $SSH_PORT"
  echo "🔁 Rolling back to port 22..."

  sed -i '/^Port/d' $SSH_CONFIG
  echo "Port 22" >> $SSH_CONFIG

  systemctl restart ssh
  exit 1
fi

echo "✅ SSH running on port $SSH_PORT"

#############################
# 7. FIREWALL
#############################

echo "🔥 Configuring firewall..."

apt install -y ufw

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

ufw allow $SSH_PORT/tcp
ufw allow 80/tcp
ufw allow 443/tcp

ufw --force enable

#############################
# 8. FAIL2BAN
#############################

echo "🛡️ Installing Fail2Ban..."

apt install -y fail2ban

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
# 9. UTILITIES
#############################

echo "🧰 Installing utilities..."

apt install -y \
  htop iotop nethogs curl git unzip \
  ca-certificates gnupg lsb-release

#############################
# 10. DOCKER
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
# 11. SYSCTL HARDENING
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
# 12. CLEANUP
#############################

echo "🧹 Cleaning up..."

apt autoremove -y
apt clean

#############################
# 13. FINAL OUTPUT
#############################

echo ""
echo "============================================================"
echo "✅ HARDENING COMPLETE"
echo "============================================================"
echo ""
echo "🔑 ACCESS DETAILS:"
echo "User: $NEW_USER"
echo "Password: $NEW_PASSWORD"
echo "SSH Port: $SSH_PORT"
echo ""
echo "👉 Connect using:"
echo "ssh -p $SSH_PORT root@SERVER_IP"
echo "ssh -p $SSH_PORT $NEW_USER@SERVER_IP"
echo ""
echo "============================================================"
