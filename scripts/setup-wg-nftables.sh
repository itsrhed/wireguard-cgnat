#!/bin/sh
# Automated setup script for WireGuard nftables management
# Installs dependencies, enables IP forwarding, installs WireGuard,
# generates keys, copies scripts and config, sets permissions,
# enables and starts the systemd watcher service.

set -e

INSTALL_DIR="/etc/wireguard"
SERVICE_DIR="/etc/systemd/system/"
SERVICE_NAME="wg-nftables-watcher.service"

# Determine if sudo is needed
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

echo "Enabling IP forwarding..."
$SUDO sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
$SUDO sysctl -p

echo "Installing dependencies..."
if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update
    $SUDO apt-get install -y inotify-tools nftables wireguard
elif command -v yum >/dev/null 2>&1; then
    $SUDO yum install -y inotify-tools nftables wireguard
else
    echo "Please install inotify-tools, nftables, and wireguard manually."
fi

echo "Creating install directory: $INSTALL_DIR"
$SUDO mkdir -p "$INSTALL_DIR"

echo "Copying files to $INSTALL_DIR"
$SUDO cp wg-nftables-watcher.service "$SERVICE_DIR/"
$SUDO cp wg-nftables.conf wg-nftables-sync.sh wg-nftables-watcher.sh wg-nftables-watcher.service "$INSTALL_DIR/"

echo "Setting executable permissions on scripts"
$SUDO chmod +x "$INSTALL_DIR/wg-nftables-sync.sh" "$INSTALL_DIR/wg-nftables-watcher.sh"

echo "Please enter the public key from your VPS WireGuard setup:"
read -r VPS_PUBLIC_KEY

echo "Please enter the VPS public IP address (Endpoint):"
read -r VPS_IP

echo "Generating WireGuard keys and initial config..."
umask 077
$SUDO sh -c "printf '[Interface]\nPrivateKey = ' > $INSTALL_DIR/wg0.conf"
$SUDO wg genkey | $SUDO tee -a $INSTALL_DIR/wg0.conf | wg pubkey | $SUDO tee $INSTALL_DIR/publickey

echo "Appending WireGuard client config snippet to $INSTALL_DIR/wg0.conf..."
$SUDO sh -c "cat >> $INSTALL_DIR/wg0.conf" <<EOF

Address = 10.0.0.2/24

[Peer]
PublicKey = $VPS_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0
Endpoint = $VPS_IP:55107
PersistentKeepalive = 25
EOF

echo "Note: Replace 'THE_PUBLIC_KEY_FROM_YOUR_VPS_WIREGUARD_INSTALL' with the actual public key from your VPS WireGuard setup."
echo "Note: Replace '1.2.3.4' with your VPS public IP address."

echo "Reloading systemd daemon"
$SUDO systemctl daemon-reload

echo "Enabling and starting $SERVICE_NAME"
$SUDO systemctl enable "$SERVICE_NAME"
$SUDO systemctl start "$SERVICE_NAME"

echo "Starting WireGuard interface wg0"
$SUDO systemctl start wg-quick@wg0
$SUDO systemctl enable wg-quick@wg0

echo "Setup complete. You can check the watcher service status with:"
echo "  $SUDO systemctl status $SERVICE_NAME"
