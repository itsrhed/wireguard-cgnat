# WireGuard nftables Management

This project provides scripts and a systemd service to manage nftables rules for WireGuard dynamically based on a configuration file. It ensures that nftables NAT rules are always synchronized with your desired configuration, preventing duplicates and stale rules.

## Files

- **wg-nftables.conf**  
  Configuration file listing the protocol, port, and destination IP for each port forwarding rule.  
  Format per line:

  ```
  protocol port destination_ip
  ```

  Example:

  ```
  tcp 1234 192.168.2.6
  udp 1194 192.168.2.7
  ```

- **wg-nftables-sync.sh**  
  Shell script that synchronizes nftables NAT rules with the entries in `wg-nftables.conf`.  
  It adds missing rules and deletes obsolete ones, ensuring nftables rules exactly match the config.

- **wg-nftables-watcher.sh**  
  Watcher script that monitors `wg-nftables.conf` for changes using `inotifywait`.  
  When the config file changes, it triggers `wg-nftables-sync.sh` to update nftables rules automatically.

- **wg-nftables-watcher.service**  
  A systemd service unit to run the watcher script as a background service, ensuring nftables rules stay in sync continuously.

## Setup and Usage

### On the Local WireGuard Server

1. **Place the files** in a suitable directory on your WireGuard server, e.g., `/etc/wireguard/`.

2. **Edit `wg-nftables.conf`** to define your port forwarding rules. Each line should specify the protocol (`tcp` or `udp`), the port number, and the destination IP address.

3. **Make scripts executable**:

   ```bash
   chmod +x wg-nftables-sync.sh wg-nftables-watcher.sh
   ```

4. **Update paths in scripts** if necessary to reflect the actual location of the config and scripts.

5. **Test the sync script manually** to apply rules initially:

   ```bash
   ./wg-nftables-sync.sh
   ```

6. **Enable and start the systemd watcher service** to keep rules in sync automatically:

   ```bash
   sudo systemctl enable wg-nftables-watcher.service
   sudo systemctl start wg-nftables-watcher.service
   ```

7. **Verify the service status**:

   ```bash
   sudo systemctl status wg-nftables-watcher.service
   ```

8. **Modify `wg-nftables.conf`** as needed. The watcher service will detect changes and update nftables rules accordingly.

### On the VPS

1. **Run the VPS setup script** to install WireGuard, enable IP forwarding, and generate keys:

   ```bash
   sudo sh setup-vps-wireguard.sh
   ```

2. **Edit `/etc/wireguard/wg0.conf`** on the VPS as instructed by the script, replacing placeholders with your actual VPS IP, interface, and client public key.

3. **Start and enable WireGuard on the VPS**:

   ```bash
   sudo systemctl start wg-quick@wg0
   sudo systemctl enable wg-quick@wg0
   ```

## Notes

- The watcher script requires `inotify-tools` to be installed for file change monitoring. Install it via your package manager, e.g., `sudo apt install inotify-tools`.

- The scripts assume nftables is installed and configured on your system.

- The nftables rules managed by these scripts are limited to NAT table PREROUTING and POSTROUTING chains for port forwarding and masquerading.

- This setup replaces the need to manually manage nftables rules in WireGuard PostUp/PostDown scripts.

## WireGuard Configuration Note

- In your WireGuard configuration file (e.g., `/etc/wireguard/wg0.conf`), the `Endpoint` field should be set to your VPS public IP and port. For example:

  ```
  Endpoint = 1.2.3.4:55107
  ```

  Here, `1.2.3.4` is the VPS endpoint IP address.

- The WireGuard private key for the server is stored in `/etc/wireguard/wg0.conf` under the `[Interface]` section as `PrivateKey`.

- The corresponding public key is saved in `/etc/wireguard/publickey` on the server. This public key must be copied and added to the `[Peer]` section of the client’s WireGuard configuration file.

- On the client side, the private key should be generated and stored securely (e.g., in `/etc/wireguard/wg0.conf`), and the public key generated from it must be added to the server’s `[Peer]` section.

- Ensure that the public keys are correctly exchanged and placed in the respective configuration files to establish a secure WireGuard connection.
  Endpoint = 1.2.3.4:55107

## Troubleshooting

- If rules are not updating as expected, check the watcher service logs:

  ```bash
  journalctl -u wg-nftables-watcher.service -f
  ```

- Ensure the config file path and script paths are correctly set in the watcher script.

- Run the sync script manually to check for errors.

## License

This project is provided as-is without warranty. Use at your own risk.
