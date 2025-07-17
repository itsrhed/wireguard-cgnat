#!/bin/sh
# Watcher script to monitor wg-nftables.conf and sync nftables rules accordingly

CONFIG_FILE="/etc/wireguard/wg-nftables.conf"
SYNC_SCRIPT="/opt/wireguard/wg-nftables-sync.sh"

LAST_CHECKSUM=""

while inotifywait -e close_write "$CONFIG_FILE"; do
    CURRENT_CHECKSUM=$(sha256sum "$CONFIG_FILE" | awk '{print $1}')
    if [ "$CURRENT_CHECKSUM" != "$LAST_CHECKSUM" ]; then
        echo "Detected change in $CONFIG_FILE, syncing nftables rules..."
        sh "$SYNC_SCRIPT"
        LAST_CHECKSUM=$CURRENT_CHECKSUM
    else
        echo "No changes detected in $CONFIG_FILE content."
    fi
done
