#!/bin/sh
# qubes-vlan-coupling installer -- run as root inside sys-net
set -e
DEST=/rw/config
SRC="$(dirname "$0")/files"

[ "$(id -u)" = 0 ] || { echo "run as root (inside sys-net)"; exit 1; }
[ -f "$SRC/qubes-firewall-user-script" ] || { echo "run from package root"; exit 1; }

echo "Installing to $DEST ..."

# conf: never overwrite an existing one
if [ -f "$DEST/vlan-coupling.conf" ]; then
    echo "  keeping existing vlan-coupling.conf"
else
    cp "$SRC/vlan-coupling.conf" "$DEST/"
    echo "  INSTALLED vlan-coupling.conf - EDIT IT: qube IPs and uplinks"
fi

cp "$SRC/qubes-firewall-user-script" "$DEST/"
cp "$SRC/vlan-coupling-watch.sh"     "$DEST/"
cp "$SRC/vlan-coupling-watcher.service" "$DEST/"
chmod 700 "$DEST/qubes-firewall-user-script" "$DEST/vlan-coupling-watch.sh"

# rc.local bootstrap: install once, idempotently
MARKER="# vlan-coupling bootstrap"
touch "$DEST/rc.local"
if ! grep -q "$MARKER" "$DEST/rc.local"; then
    cat "$SRC/rc.local.snippet" >> "$DEST/rc.local"
    chmod +x "$DEST/rc.local"
    echo "  appended bootstrap to rc.local"
fi

# start now if conf already exists (upgrade case)
if [ -f /etc/systemd/system/vlan-coupling-watcher.service ]; then
    ln -sf "$DEST/vlan-coupling-watcher.service" /etc/systemd/system/
    systemctl daemon-reload
    systemctl restart vlan-coupling-watcher
    echo "Started."
else
    echo
    echo "Done. Next steps:"
    echo "  1. Edit $DEST/vlan-coupling.conf for your qubes/VLANs"
    echo "  2. Reboot sys-net, or: systemctl enable --now vlan-coupling-watcher"
    echo "     (after: ln -s $DEST/vlan-coupling-watcher.service /etc/systemd/system/; systemctl daemon-reload)"
fi
