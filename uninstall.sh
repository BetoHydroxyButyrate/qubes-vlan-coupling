#!/bin/sh
# run as root inside sys-net
set -e
systemctl disable --now vlan-coupling-watcher 2>/dev/null || true
rm -f /etc/systemd/system/vlan-coupling-watcher.service
systemctl daemon-reload
nft delete table ip vlan_coupling 2>/dev/null || true
for p in $(seq 5000 5999); do
    while ip rule del pref "$p" 2>/dev/null; do :; done
done
rm -f /rw/config/.vlan_coupling.state
echo "Removed service, nft table, and ip rules."
echo "Kept (remove manually if desired):"
echo "  /rw/config/vlan-coupling.conf"
echo "  /rw/config/qubes-firewall-user-script"
echo "  /rw/config/vlan-coupling-watch.sh"
echo "  /rw/config/vlan-coupling-watcher.service"
echo "  rc.local bootstrap (lines marked 'vlan-coupling bootstrap')"
