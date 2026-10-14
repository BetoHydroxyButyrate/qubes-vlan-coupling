#!/bin/sh
# Event-driven watcher for Qubes VLAN coupling.
# Any NetworkManager device/connection event (vif plug from a firewall
# qube starting, link flap, DHCP change) triggers a refresh. The
# fingerprint guard in the firewall script makes idle runs no-ops.
SCRIPT=/rw/config/qubes-firewall-user-script
LOGTAG=vlan-coupling
STATE=/rw/config/.vlan-coupling.state

log(){ logger -t "$LOGTAG" -- "$*"; }
script() { ${SCRIPT} >/dev/null 2>&1; }

while true; do
    log "watcher starting: clearing stale state"
    rm -f ${STATE}

    "$SCRIPT" >/dev/null 2>&1
    nmcli monitor | while read -r event; do
	log event:${event}
	[[ "${event}" =~ ": device created" ]] && {
	    sleep 2              # let vif routes / DHCP settle
	    script
	}
	[[ "${event}" =~ ": device removed" ]] && {
	    sleep 2              # let vif routes / DHCP settle
	    script
	}
	[[ "${event}" =~ ": connected" ]] && {
	    sleep 2              # let vif routes / DHCP settle
	    script
	}
    done
    log "monitor quit"
    sleep 10                 # nmcli monitor died (NM restart) - reconnect
done
