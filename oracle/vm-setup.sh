#!/usr/bin/env bash
# =====================================================================
# Template for setting up the anchor service on an OCI Ubuntu VM.
# NOT TESTED on a live OCI VM - read each step, run them one at a time, and adjust.
# Run on the VM as the default "ubuntu" user:   bash vm-setup.sh
#
# BEFORE running:
#   - In the OCI console, open ports 80 and 443 in the VM's subnet Security List (Ingress rules, 0.0.0.0/0, TCP).
#   - Know your public hostname. Easiest free option: use  <your-public-ip-with-dashes>.sslip.io
#       e.g. IP 152.67.10.20  ->  152-67-10-20.sslip.io    (Caddy can fetch a real certificate for it)
#     A real domain (or a DuckDNS name) also works. ADB requires a TRUSTED https certificate.
# =====================================================================
set -euo pipefail

HOSTNAME_FOR_TLS="${1:-}"   # usage: bash vm-setup.sh 152-67-10-20.sslip.io
if [ -z "$HOSTNAME_FOR_TLS" ]; then echo "Usage: bash vm-setup.sh <your-hostname>"; exit 1; fi

echo "== 1. System packages and Node.js 20 =="
sudo apt-get update -y
sudo apt-get install -y curl unzip debian-keyring debian-archive-keyring apt-transport-https
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

echo "== 2. Open the VM's own firewall (Oracle Ubuntu images block 80/443 by default) =="
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80  -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save || true

echo "== 3. Caddy (gives you automatic https) =="
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update -y && sudo apt-get install -y caddy
sudo tee /etc/caddy/Caddyfile > /dev/null <<EOF
${HOSTNAME_FOR_TLS} {
    reverse_proxy localhost:8080
}
EOF
sudo systemctl restart caddy

echo "== 4. The anchor service =="
# Upload the anchor-service folder first, e.g. from your laptop:
#   scp -r anchor-service ubuntu@<vm-ip>:~/anchor-service
cd ~/anchor-service
npm install --omit=dev
if [ ! -f .env ]; then cp .env.example .env; echo ">> Edit ~/anchor-service/.env now (API_KEY, CONTRACT_ADDRESS, ISSUER_PRIVATE_KEY, VERIFY_BASE_URL), then re-run: sudo systemctl restart mut-anchor"; fi
chmod 600 .env

echo "== 5. Run it as a background service that restarts on crash/reboot =="
sudo tee /etc/systemd/system/mut-anchor.service > /dev/null <<EOF
[Unit]
Description=MUT-Verify anchor service
After=network.target

[Service]
WorkingDirectory=/home/ubuntu/anchor-service
ExecStart=/usr/bin/node src/server.js
Restart=always
User=ubuntu
EnvironmentFile=/home/ubuntu/anchor-service/.env

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now mut-anchor
sleep 2
sudo systemctl status mut-anchor --no-pager | head -12
echo
echo "Test from your laptop:   curl https://${HOSTNAME_FOR_TLS}/health"
