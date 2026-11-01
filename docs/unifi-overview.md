# UniFi current state (sanitized, public)

Live source: read-only API via `scripts/unifi-ro-get.sh`.
This file intentionally omits names, versions, ports, and host IPs
beyond what the repo already states. Full detail lives in
`.private/unifi-overview.md` (gitignored, never committed).

## Console

- UDM-Pro gateway. Policy Engine upgraded to the zone-based firewall.
  All subsystems healthy. The VPN flag is cosmetic: the SD-WAN mesh to both remote sites passes traffic; dead legacy tunnels removed.

## Networks

- Main LAN, untagged, `192.168.0.0/21` (see `talos/node/k8s-*/02-network.yaml`).
- IoT VLAN, DHCP with filtered DNS.
- Storage VLAN (Talos static clients, DHCP disabled).
- Remote-access VPN is WireGuard (subnet in private file). Teleport is
  disabled: its fixed client pool overlapped the main LAN.
- Guest VLAN with own subnet, Hotspot zone, filtered DNS, DHCP pool at
  the top of the range.

Repo consumers: Talos nodes `192.168.1.10`–`.14`, Blocky main pair,
Blocky filtered pair (IoT + Guest, no internal zones, ad + smart-TV
blocking), k8s-gateway `.6.100`, Envoy `.6.202`/`.6.203`
(see `kubernetes/apps/kube-system/cilium/app/networks.yaml`,
`kubernetes/apps/network/*`).

## WLANs

- One primary SSID plus legacy/household SSIDs on main LAN (3 total,
  see private file; Chez-Palmer removed 2026-10-31). SSID count still
  exceeds need.
- Separate IoT and Guest SSIDs on their own VLANs/subnets. Guest is
  open with guest isolation; client test passed.

## Firewall

- Zone-based: guests get return-only access toward internal zones,
  full access outward, nothing toward other guest/DMZ zones.
- Explicit DNS exception lets guests reach only the two filtered DNS
  IPs on port 53.
- IoT shares the Internal zone with main and storage, so custom
  policies do the segmenting (reviewed 2026-11-01, 10 custom policies
  after removing the rules the Policy Engine migration cloned into
  every zone pair):
  - IoT may reach the filtered DNS pair, the media server, the MQTT
    broker and NTP; everything else toward main and storage is blocked.
  - Blocked as well: IoT toward VPN clients and remote sites, toward the
    gateway's management and DNS ports, and toward outside DNS (53,
    853). DNS-over-HTTPS can't be blocked by port.
  - Replies to connections started from main still pass.
  - Every custom block logs; device syslog and firewall logs go to Loki
    through Alloy.
- mDNS is reflected only between main and IoT.
- IPS runs in notify mode (detect, don't block).

## Port forwards (reviewed 2026-10-31)

- Two WAN port forwards exist (media server and one other). Targets
  and ports are in the private file. Both are intentional: Plex remote
  uses its direct port, the torrent client needs its inbound peer port
  (UDP now open to match). Web UIs stay internal-only.

## Remaining gaps

1. SSID sprawl on main (3 SSIDs, one network, was 4 — Palmer
   migration deferred).
2. Cilium LB pool shrunk 2026-10-31 (pool object live, all VIPs kept).
3. No IaC for UniFi config. Automatic cloud backups are on.
4. Network boot is off until netboot.xyz has a live server
   (`home-ops-netboot-hn2`).
