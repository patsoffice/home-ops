# UniFi current state (sanitized, public)

Live source: read-only API via `scripts/unifi-ro-get.sh`.
This file intentionally omits names, versions, ports, and host IPs
beyond what the repo already states. Full detail lives in
`.private/unifi-overview.md` (gitignored, never committed).

## Console

- UDM-Pro gateway. All subsystems healthy except VPN (inactive
  site-to-site tunnels present, no active remote clients).

## Networks

- Main LAN, untagged, `192.168.0.0/21` (see `talos/node/k8s-*/02-network.yaml`).
- IoT VLAN (tagged; see private file for ID/subnet).
- Storage VLAN (tagged; Talos static `10.30.1.x`, DHCP disabled).
- Remote-access VPN subnet exists (see private file).

Repo consumers: Talos nodes `192.168.1.10`–`.14`, Blocky
`.0.100`–`.103`, k8s-gateway `.6.100`, Envoy `.6.202`/`.6.203`
(see `kubernetes/apps/kube-system/cilium/app/networks.yaml`,
`kubernetes/apps/network/*`).

## WLANs

- One primary SSID plus legacy/household SSIDs on main LAN (4 total,
  see private file). SSID count exceeds need.
- Separate IoT and Guest SSIDs exist, but both currently land in the
  same IoT subnet. Guest shares a broadcast domain with IoT.

## Firewall

- LAN_IN allows established, NTP, and remote-VPN traffic, then a set
  of IoT-specific allows (home automation, media, DNS, MQTT), then a
  drop for IoT to LAN. The drop's index numbering makes the order
  fragile: allows are numbered both above and below it.
- One address-group member references a subnet with no matching
  network (stale entry, see private file).

## Port forwards

- Two WAN port forwards exist (media server and one other). Targets
  and ports are in the private file. Both are under review for
  necessity and tunnel redundancy.

## Known gaps before changes

1. Guest and IoT share one VLAN/subnet.
2. SSID sprawl on main (4 SSIDs, one network).
3. Firewall index numbering invites misordering.
4. Stale address-group member.
5. Cilium LB pool is the whole `/21` (collision risk with DHCP/statics).
6. No IaC or backup record for UniFi config.
