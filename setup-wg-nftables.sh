#!/bin/sh
# Automated setup script for WireGuard nftables management
# Installs dependencies, enables IP forwarding, installs WireGuard,
# generates keys, copies scripts and config, sets permissions,
# enables and starts the systemd watcher service.

set -e

INSTALL_DIR="/etc/wireguard"
SERVICE_NAME="wg-nftables-watcher.service"

echo "Enabling IP forwarding..."
sudo sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p

echo "Installing dependencies..."
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y inotify-tools nftables wireguard
elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y inotify-tools nftables wireguard
else
    echo "Please install inotify-tools, nftables, and wireguard manually."
fi

echo "Creating install directory: $INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"

echo "Copying files to $INSTALL_DIR"
sudo cp wg-nftables.conf wg-nftables-sync.sh wg-nftables-watcher.sh wg-nftables-watcher.service "$INSTALL_DIR/"

echo "Setting executable permissions on scripts"
sudo chmod +x "$INSTALL_DIR/wg-nftables-sync.sh" "$INSTALL_DIR/wg-nftables-watcher.sh"

echo "Generating WireGuard keys and initial config..."
sudo umask 077
sudo sh -c "printf '[Interface]\nPrivateKey = ' > $INSTALL_DIR/wg0.conf"
sudo wg genkey | sudo tee -a $INSTALL_DIR/wg0.conf | wg pubkey | sudo tee $INSTALL_DIR/publickey

echo "Please copy the public key from $INSTALL_DIR/publickey and add it to your VPS WireGuard config."

echo "You may need to edit $INSTALL_DIR/wg0.conf to add the following (adjust as needed):"
echo "
[Interface]
PrivateKey = (already filled)
Address = 10.0.0.2/24

[Peer]
PublicKey = THE_PUBLIC_KEY_FROM_YOUR_VPS_WIREGUARD_INSTALL
AllowedIPs = 0.0.0.0/0
Endpoint = 1.2.3.4:55107
PersistentKeepalive = 25
"

echo "Reloading systemd daemon"
sudo systemctl daemon-reload

echo "Enabling and starting $SERVICE_NAME"
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

echo "Starting WireGuard interface wg0"
sudo systemctl start wg-quick@wg0
sudo systemctl enable wg-quick@wg0

echo "Setup complete. You can check the watcher service status with:"
echo "  sudo systemctl status $SERVICE_NAME"
