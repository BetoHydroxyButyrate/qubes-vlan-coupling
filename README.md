# qubes-vlan-coupling

Per-VLAN egress for Qubes OS: route each sys-firewall qube's traffic out a
specific VLAN interface in sys-net, with deterministic per-VLAN DNS and
automatic recovery from reboots, qube starts, and link flaps.

Developed and tested on Qubes OS 4.3 with a Fedora-based sys-net template
(nftables, NetworkManager). The design concept and debugging methodology
were developed collaboratively with Luma (Proton's AI assistant); the
fqmk-per-vif approach, the flowtable bypass, and the nmcli monitor trigger
originated in that dialogue. Contributions welcome.

## What it does

Qubes routes (not bridges) VM traffic: each network-providing qube is a
router hop, and sys-net masquerades egress per-interface. This package
extends that model with:

- **fwmark policy routing** -- packets from each coupled firewall qube's
  vif are marked in prerouting; the mark selects a per-VLAN routing table.
  Marks derive from the VLAN tag (ens7.13 -> 0x100d), so they are stable
  and readable in `nft`/`ip rule` dumps.
- **Deterministic DNS** -- DNS from each coupled qube is DNAT'd to that
  VLAN's resolver (DHCP-learned, or pinned per conf entry), optionally
  intercepting direct-to-public queries (8.8.8.8 etc.) so DNS always exits
  the correct VLAN. Keyed on the vif, independent of mark numbering.
- **Flowtable bypass** -- rules in `inet qubes-nat-accel` keep coupled
  vifs on the slow path; flowtable offload would skip prerouting, where
  marks are set, breaking established flows.
- **Event-driven convergence** -- a watcher (systemd service) reacts to
  NetworkManager device events. A state fingerprint makes idle runs
  no-ops, so the system only rebuilds when the world actually changed.
  Rebuilds sweep stale ip rules and converge from any partial state.

Traffic for qubes *behind* a coupled firewall is inherited: it arrives
masqueraded as the firewall's IP on the firewall's vif, riding the
firewall's VLAN. VLAN assignment granularity is therefore per-firewall-qube,
not per-AppVM.

## Requirements

- Qubes OS 4.3 (developed on; 4.2 with native nftables qubes-firewall
  may work but is untested)
- Fedora-based sys-net template (uses nmcli, nft, logger, mktemp)
- VLAN subinterfaces configured in sys-net (e.g. via `nmcli con add
  type vlan ...` with `ipv4.never-default yes` on non-primary uplinks)

## Installation

From inside sys-net, as root, with this directory present:

    ./install.sh

Then edit `/rw/config/vlan-coupling.conf` for your environment:
one line per DIRECTLY-ATTACHED network-providing qube:

    <qube-ip>   <uplink-iface>   [<dns-override>]

Find qube IPs via `qvm-ls -n` (dom0) or `ip -o route get` (sys-net).
Only list qubes whose vif lives in sys-net (firewall qubes directly
attached to sys-net). Restart the service after conf edits, or wait for
any NM device event.

## Files

- `vlan-coupling.conf`         -- your policy (survives reinstall)
- `qubes-firewall-user-script` -- the core script: discovery, marks,
                                 DNS interception, fingerprint state
- `vlan-coupling-watch.sh`     -- watcher loop (nmcli monitor)
- `vlan-coupling-watcher.service` -- systemd unit for the watcher
- `rc.local.snippet`            -- boot bootstrap, merged into rc.local

## Troubleshooting

    journalctl -t vlan-coupling           # what happened and when
    systemctl status vlan-coupling-watcher
    nft list table ip vlan_coupling       # marks + DNS rules
    ip rule list                          # pref 5000-5999 = ours
    conntrack -L | grep dport=53          # verify per-VLAN DNS + masquerade

Band-aid for any weirdness: `systemctl restart vlan-coupling-watcher`
clears state, sweeps stale ip rules, and forces a full rebuild.

## Known limits

- IPv4 only (IPv6 tables are not coupled).
- Coupling is per-firewall-qube; downstream AppVMs inherit their
  firewall's VLAN and cannot be individually overridden.
- `nmcli monitor` output format is not a guaranteed ABI; re-verify
  after major template upgrades.

## Credits

Design developed collaboratively with **Lumo** (Proton AI) -- including
the mark-before-DNAT priority scheme, the conntrack-based verification
methodology, and the fingerprint/idempotency model. The package author
contributed the fwmark-per-vif insight, the flowtable bypass, and the
`nmcli monitor` event trigger.
