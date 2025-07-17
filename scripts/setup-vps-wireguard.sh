#!/bin/sh
# Setup script for WireGuard on VPS with forwarding and nftables rules
# Enables IP forwarding, installs WireGuard, generates keys, creates initial config,
# and appends necessary PostUp/PostDown rules with automatic VPS IP detection.

set -e

echo "Enabling IP forwarding..."
sudo sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p

echo "Updating package lists and upgrading..."
sudo apt update && sudo apt upgrade -y

echo "Installing WireGuard..."
sudo apt install -y wireguard

echo "Generating WireGuard keys..."
umask 077
sudo sh -c "printf '[Interface]\nPrivateKey = ' > /etc/wireguard/wg0.conf"
sudo wg genkey | sudo tee -a /etc/wireguard/wg0.conf | wg pubkey | sudo tee /etc/wireguard/publickey

echo "WireGuard keys generated."
echo "Public key is saved in /etc/wireguard/publickey. Keep it safe and use it in your client config."

# Detect VPS public IP
VPS_IP=$(curl -s https://ipinfo.io/ip)
if [ -z "$VPS_IP" ]; then
    echo "Failed to detect VPS public IP. Please enter it manually:"
    read -r VPS_IP
fi
echo "Detected VPS public IP: $VPS_IP"

echo "Please enter the WireGuard server IP address (default: 10.0.0.1):"
read -r SERVER_IP
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="10.0.0.1"
fi

echo "Please enter the WireGuard client IP address (default: 10.0.0.2):"
read -r CLIENT_IP
if [ -z "$CLIENT_IP" ]; then
    CLIENT_IP="10.0.0.2"
fi

# Append configuration to wg0.conf
cat <<EOF | sudo tee -a /etc/wireguard/wg0.conf

ListenPort = 55107
Address = $SERVER_IP/24

PostUp = iptables -t nat -A PREROUTING -p tcp -i eth0 '!' --dport 22 -j DNAT --to-destination $CLIENT_IP; iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to-source $VPS_IP
PostUp = iptables -t nat -A PREROUTING -p udp -i eth0 '!' --dport 55107 -j DNAT --to-destination $CLIENT_IP;

PostDown = iptables -t nat -D PREROUTING -p tcp -i eth0 '!' --dport 22 -j DNAT --to-destination $CLIENT_IP; iptables -t nat -D POSTROUTING -o eth0 -j SNAT --to-source $VPS_IP
PostDown = iptables -t nat -D PREROUTING -p udp -i eth0 '!' --dport 55107 -j DNAT --to-destination $CLIENT_IP;

[Peer]
PublicKey = (client public key here)
AllowedIPs = $CLIENT_IP/32
EOF

echo "Please edit /etc/wireguard/wg0.conf to replace '(client public key here)' with your client's public key."
echo "Replace 'eth0' with your internet-facing interface if different."

echo "Starting WireGuard interface wg0..."
sudo systemctl start wg-quick@wg0
sudo systemctl enable wg-quick@wg0

echo "Setup complete. Test connectivity by pinging 10.0.0.2 from your VPS."
