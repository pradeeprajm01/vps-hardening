#!/bin/bash

set -e

echo "============================================================"
echo "🚀 Ubuntu Bootstrap Script (Clean + Optional SSH Port)"
echo "============================================================"
echo ""

#############################
# 1. DEFAULTS
#############################

DEFAULT_USER="test"
DEFAULT_PASSWORD="test"
DEFAULT_SSH_PORT=22

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

# Git config input
read -p "Enter Git username (leave empty to skip): " GIT_USER
read -p "Enter Git email (leave empty to skip): " GIT_EMAIL

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
# 6. SSH PORT CONFIG (MINIMAL)
#############################

echo "🔐 Configuring SSH port..."

SSH_CONFIG="/etc/ssh/sshd_config"

# Backup
cp $SSH_CONFIG ${SSH_CONFIG}.bak

# Remove existing Port entries
sed -i '/^Port/d' $SSH_CONFIG

# Apply new port
echo "Port $SSH_PORT" >> $SSH_CONFIG

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
# 7. FIREWALL (SAFE ORDER)
#############################

echo "🔥 Configuring firewall..."

apt install -y ufw

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# CRITICAL: Allow SSH BEFORE enabling firewall
ufw allow $SSH_PORT/tcp
ufw allow 80/tcp
ufw allow 443/tcp

ufw --force enable

#############################
# 8. GIT CONFIG (SAFE)
#############################

echo "🔧 Configuring Git (if provided)..."

if [ -n "$GIT_USER" ] && [ -n "$GIT_EMAIL" ]; then
    EXISTING_USER=$(git config --global user.name || true)
    EXISTING_EMAIL=$(git config --global user.email || true)

    if [ "$EXISTING_USER" != "$GIT_USER" ]; then
        git config --global user.name "$GIT_USER"
    fi

    if [ "$EXISTING_EMAIL" != "$GIT_EMAIL" ]; then
        git config --global user.email "$GIT_EMAIL"
    fi

    echo "✅ Git configured"
else
    echo "ℹ️ Skipping Git config"
fi

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
# 11. SYSCTL (LIGHT HARDENING)
#############################

echo "⚙️ Applying kernel tuning..."

cat <<EOF >> /etc/sysctl.conf

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
echo "✅ SETUP COMPLETE"
echo "============================================================"
echo ""
echo "🔑 ACCESS DETAILS:"
echo "User: $NEW_USER"
echo "Password: $NEW_PASSWORD"
echo "SSH Port: $SSH_PORT"
echo ""
echo "👉 Connect using:"
echo "ssh -p $SSH_PORT $NEW_USER@SERVER_IP"
echo ""
echo "============================================================"
