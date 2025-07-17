#!/bin/sh
# Setup script for WireGuard on VPS with forwarding and nftables rules
# Enables IP forwarding, installs WireGuard, generates keys, and creates initial config

set -e

echo "Enabling IP forwarding..."
sudo sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p

echo "Updating package lists and upgrading..."
sudo apt update && sudo apt upgrade -y

echo "Installing WireGuard..."
sudo apt install -y wireguard

echo "Generating WireGuard keys..."
sudo umask 077
sudo sh -c "printf '[Interface]\nPrivateKey = ' > /etc/wireguard/wg0.conf"
sudo wg genkey | sudo tee -a /etc/wireguard/wg0.conf | wg pubkey | sudo tee /etc/wireguard/publickey

echo "WireGuard keys generated."
echo "Public key is saved in /etc/wireguard/publickey. Keep it safe and use it in your client config."

echo "Please edit /etc/wireguard/wg0.conf to add the following configuration (adjust IPs and ports as needed):"
echo "
[Interface]
PrivateKey = (already filled)
ListenPort = 55107
Address = 10.0.0.1/24

PostUp = iptables -t nat -A PREROUTING -p tcp -i eth0 '!' --dport 22 -j DNAT --to-destination 10.0.0.2; iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to-source 1.2.3.4
PostUp = iptables -t nat -A PREROUTING -p udp -i eth0 '!' --dport 55107 -j DNAT --to-destination 10.0.0.2;

PostDown = iptables -t nat -D PREROUTING -p tcp -i eth0 '!' --dport 22 -j DNAT --to-destination 10.0.0.2; iptables -t nat -D POSTROUTING -o eth0 -j SNAT --to-source 1.2.3.4
PostDown = iptables -t nat -D PREROUTING -p udp -i eth0 '!' --dport 55107 -j DNAT --to-destination 10.0.0.2;

[Peer]
PublicKey = (client public key here)
AllowedIPs = 10.0.0.2/32
"

echo "Replace '1.2.3.4' with your VPS public IP and 'eth0' with your internet-facing interface if different."
echo "After editing, start WireGuard with:"
echo "  sudo systemctl start wg-quick@wg0"
echo "  sudo systemctl enable wg-quick@wg0"
echo "Test connectivity by pinging 10.0.0.2 from your VPS."
