#!/bin/sh

CONFIG_FILE="/etc/wireguard/wg-nftables.conf"

# Create NAT table and chains if they don't exist
nft list table ip nat >/dev/null 2>&1 || nft add table ip nat
nft list chain ip nat prerouting >/dev/null 2>&1 || \
    nft add chain ip nat prerouting { type nat hook prerouting priority -100 \; }
nft list chain ip nat postrouting >/dev/null 2>&1 || \
    nft add chain ip nat postrouting { type nat hook postrouting priority 100 \; }

# Read config into memory
CONFIG_PREROUTING=$(mktemp)
CONFIG_POSTROUTING=$(mktemp)

while read -r proto port dest; do
    [ -z "$proto" ] && continue
    case "$proto" in
        \#*|"") continue ;;
    esac
    # Correct nftables syntax for dnat and masquerade rules
    echo "meta l4proto $proto tcp dport $port dnat to $dest:$port" >> "$CONFIG_PREROUTING"
    echo "meta l4proto $proto tcp dport $port masquerade" >> "$CONFIG_POSTROUTING"
done < "$CONFIG_FILE"

# Delete outdated prerouting rules
nft --handle list chain ip nat prerouting | grep -E 'dnat to' | while read -r line; do
    handle=$(echo "$line" | sed -n 's/.*handle \([0-9]\+\).*/\1/p')
    rule_str=$(echo "$line" | sed -E 's/\s*handle [0-9]+//')

    # Normalize rule string for matching
    echo "$rule_str" | grep -Fxq -f "$CONFIG_PREROUTING" || {
        echo "Deleting old prerouting rule: $rule_str"
        nft delete rule ip nat prerouting handle "$handle"
    }
done

# Delete outdated postrouting rules
nft --handle list chain ip nat postrouting | grep -E 'masquerade' | while read -r line; do
    handle=$(echo "$line" | sed -n 's/.*handle \([0-9]\+\).*/\1/p')
    rule_str=$(echo "$line" | sed -E 's/\s*handle [0-9]+//')

    echo "$rule_str" | grep -Fxq -f "$CONFIG_POSTROUTING" || {
        echo "Deleting old postrouting rule: $rule_str"
        nft delete rule ip nat postrouting handle "$handle"
    }
done

# Add missing prerouting rules
while read -r rule; do
    nft list chain ip nat prerouting | grep -F -- "$rule" >/dev/null 2>&1 || {
        echo "Adding new prerouting rule: $rule"
        nft add rule ip nat prerouting $rule
    }
done < "$CONFIG_PREROUTING"

# Add missing postrouting rules
while read -r rule; do
    nft list chain ip nat postrouting | grep -F -- "$rule" >/dev/null 2>&1 || {
        echo "Adding new postrouting rule: $rule"
        nft add rule ip nat postrouting $rule
    }
done < "$CONFIG_POSTROUTING"

rm -f "$CONFIG_PREROUTING" "$CONFIG_POSTROUTING"