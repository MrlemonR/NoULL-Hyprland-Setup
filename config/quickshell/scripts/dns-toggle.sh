#!/usr/bin/env bash
#
# Encrypted DNS (DNS-over-TLS), to get past DNS-level blocks.
#
# The ISP resolver answers blocked domains with a sentinel IP (195.175.254.2)
# instead of the real one. Asking Quad9/Cloudflare/Google directly over TLS
# takes the ISP out of the loop; nothing else about the connection changes.
#
#   sudo dns-toggle.sh            flip it (on if off, off if on)
#   sudo dns-toggle.sh --on       always on
#   sudo dns-toggle.sh --off      always off
#   dns-toggle.sh --status        report only, no root needed
#
# The control centre in the bar reads --status and shells out to this script
# through a terminal for the rest, because everything but --status needs root.
set -e

CONF_FILE=/etc/systemd/resolved.conf.d/99-encrypted-dns.conf

is_active() { [ -f "$CONF_FILE" ]; }

require_root() {
    [ "$EUID" -eq 0 ] || { echo "run with sudo: sudo $0 $*"; exit 1; }
}

verify() {
    systemctl restart systemd-networkd
    systemctl restart systemd-resolved
    sleep 3
    resolvectl flush-caches

    echo
    echo "=== STATE ==="
    resolvectl status | grep -E 'Protocols|Current DNS' | head -4
    echo
    echo "=== TEST ==="
    for d in discord.com roblox.com newgrounds.com; do
        ip=$(getent ahostsv4 "$d" | awk '{print $1}' | head -1)
        if [ "$ip" = "195.175.254.2" ]; then st="STILL BLOCKED"; else st="OK"; fi
        printf "%-18s %-16s %s\n" "$d" "${ip:-?}" "$st"
    done
}

enable_dns() {
    install -Dm644 /dev/stdin "$CONF_FILE" <<'CONF'
[Resolve]
# The ISP resolver returns a sentinel IP (195.175.254.2) for blocked domains.
# Over DNS-over-TLS we ask Quad9/Cloudflare/Google directly instead.
DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
FallbackDNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 8.8.8.8#dns.google
DNSOverTLS=yes
# Send every query to the global (encrypted) servers, not the ISP resolver
# handed out by DHCP.
Domains=~.
CONF

    for n in 20-ethernet 20-wlan 20-wwan; do
        install -Dm644 /dev/stdin /etc/systemd/network/$n.network.d/no-dhcp-dns.conf <<'CONF'
[DHCPv4]
UseDNS=false
UseDomains=false

[DHCPv6]
UseDNS=false
UseDomains=false

[IPv6AcceptRA]
UseDNS=false
UseDomains=false
CONF
    done

    echo ">>> Encrypted DNS ENABLED."
    verify
}

disable_dns() {
    rm -f "$CONF_FILE"
    rm -f /etc/systemd/network/20-{ethernet,wlan,wwan}.network.d/no-dhcp-dns.conf
    rmdir --ignore-fail-on-non-empty /etc/systemd/resolved.conf.d \
        /etc/systemd/network/20-{ethernet,wlan,wwan}.network.d 2>/dev/null || true

    echo ">>> Encrypted DNS DISABLED (back to the ISP resolver)."
    verify
}

case "${1:-}" in
    --on|--enable)
        require_root "$1"
        is_active && { echo "Already on, nothing to do."; exit 0; }
        enable_dns
        ;;
    --off|--disable)
        require_root "$1"
        is_active || { echo "Already off, nothing to do."; exit 0; }
        disable_dns
        ;;
    --status)
        # The only mode the bar calls directly: reading the file needs no root.
        if is_active; then echo on; else echo off; fi
        ;;
    --status-verbose)
        if is_active; then echo "State: ON (encrypted DNS)"; else echo "State: OFF (ISP DNS)"; fi
        resolvectl status | grep -E 'Protocols|Current DNS' | head -4
        ;;
    "")
        require_root
        if is_active; then disable_dns; else enable_dns; fi
        ;;
    *)
        echo "unknown option: $1"
        echo "usage: sudo $0 [--on | --off | --status]"
        exit 1
        ;;
esac
