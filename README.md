# 🔐 Ubuntu Hardening & Bootstrap Script (Production-Ready)

---

## 📌 1. Purpose

This script provides a **repeatable, automated baseline hardening layer** for Ubuntu/Debian-based virtual machines.

It is designed for:

* Cloud VPS (Hetzner, AWS EC2, GCP Compute Engine)
* Self-hosted infrastructure
* Container-first workloads (Docker, OpenClaw, Java apps)

---

## 🎯 2. Objectives

| Objective                | Description                            |
| ------------------------ | -------------------------------------- |
| Reduce Attack Surface    | Disable unnecessary access paths       |
| Enforce Secure Access    | SSH key-based authentication           |
| Prevent Brute Force      | Fail2Ban integration                   |
| Control Network Exposure | Firewall with deny-by-default          |
| Prepare Runtime          | Docker installation                    |
| Establish Baseline       | Standardized infra across environments |

---

## 🧠 3. High-Level Architecture (Post Execution)

```
                Internet
                    ↓
              [ UFW Firewall ]
                    ↓
                [ SSH ]
                    ↓
            [ Non-root User ]
                    ↓
         ┌──────────────────────┐
         │   Docker Runtime     │
         │  (OpenClaw / Java)   │
         └──────────────────────┘
```

---

## ⚙️ 4. Execution Flow (Detailed)

### 4.1 System Update

```
apt update && apt upgrade -y
```

Ensures latest patches and package stability.

---

### 4.2 User Provisioning

* Username: `test`
* Password: `test`
* Added to `sudo` group

Purpose: Avoid root usage and enforce privilege separation.

---

### 4.3 SSH Hardening

File: `/etc/ssh/sshd_config`

| Setting                | Value | Impact               |
| ---------------------- | ----- | -------------------- |
| PermitRootLogin        | no    | Blocks root login    |
| PasswordAuthentication | no    | Prevents brute-force |
| PubkeyAuthentication   | yes   | Enables SSH keys     |
| Port                   | 2222  | Reduces scan noise   |

---

### 4.4 Firewall (UFW)

Default:

```
deny incoming
allow outgoing
```

Allowed:

* 2222 (SSH)
* 80 (HTTP)
* 443 (HTTPS)

---

### 4.5 Fail2Ban

```
[sshd]
enabled = true
port = 2222
maxretry = 5
bantime = 3600
```

Blocks repeated failed SSH attempts.

---

### 4.6 Utilities Installed

* htop
* iotop
* nethogs
* curl
* git
* unzip

---

### 4.7 Docker Installation

Installs:

* docker-ce
* docker-cli
* containerd
* docker-compose-plugin

User added to docker group.

---

### 4.8 Kernel Hardening

```
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.tcp_syncookies=1
```

Protects against spoofing, MITM, and SYN floods.

---

### 4.9 Service Hardening

Disables:

* avahi-daemon

---

## 🔐 5. Security Coverage

| Layer     | Protection    |
| --------- | ------------- |
| Network   | UFW           |
| Access    | SSH hardening |
| Intrusion | Fail2Ban      |
| Kernel    | sysctl        |
| Runtime   | Docker ready  |

---

## ⚠️ 6. Risks & Limitations

* Weak credentials (`test/test`) – for dev only
* No SSL
* No reverse proxy
* No monitoring
* No secrets management

---

## 🚀 7. Usage

### Upload

```
scp harden.sh root@SERVER_IP:/root/
```

### Execute

```
chmod +x harden.sh
sudo ./harden.sh
```

### Verify

```
ssh -p 2222 test@SERVER_IP
```

---

## 🔍 8. Verification Checklist

| Check    | Command                     |
| -------- | --------------------------- |
| SSH Port | ss -tulnp | grep 2222       |
| Firewall | ufw status                  |
| Fail2Ban | fail2ban-client status sshd |
| Docker   | docker ps                   |
| User     | id test                     |

---

## 🧩 9. OpenClaw Context

Common issues observed:

* Docker permission errors
* Gateway restart loops
* Token authentication issues
* CORS restrictions

This script prepares base infra but does NOT configure OpenClaw.

---

## 📈 10. Next Steps

Mandatory:

* Nginx setup
* SSL (Certbot)
* Domain configuration

Advanced:

* Cloudflare (WAF)
* Tailscale (private networking)
* Vault (secrets)
* Monitoring stack

---

## 🧨 11. Failure Scenarios

| Issue         | Cause               | Fix                |
| ------------- | ------------------- | ------------------ |
| SSH lockout   | No key setup        | Use console access |
| Docker errors | Permission mismatch | chown 1000         |
| Blocked ports | UFW rules           | Adjust firewall    |
| Fail2Ban ban  | Too many retries    | Whitelist IP       |

---

## 🧠 12. Design Principles

* Least Privilege
* Defense in Depth
* Zero Trust Networking
* Automation-first infra

---

## 🏁 13. Conclusion

This script provides a **secure baseline**, not a full production setup.

Use it as the foundation for:

* OpenClaw deployment
* Java applications
* Scalable infrastructure

---
