# UniFi current state (sanitized, public)

Live source: read-only API via `scripts/unifi-ro-get.sh`.
This file intentionally omits names, versions, ports, and host IPs
beyond what the repo already states. Full detail lives in
`.private/unifi-overview.md` (gitignored, never committed).

## Console

- UDM-Pro gateway. Policy Engine upgraded to the zone-based firewall.
  All subsystems healthy except VPN (inactive site-to-site tunnels).

## Networks

- Main LAN, untagged, `192.168.0.0/21` (see `talos/node/k8s-*/02-network.yaml`).
- IoT VLAN, DHCP with filtered DNS.
- Storage VLAN (Talos static clients, DHCP disabled).
- Remote-access VPN subnet exists (see private file).
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
  IPs on port 53. IoT needs no exception (same zone as DNS).

## Port forwards

- Two WAN port forwards exist (media server and one other). Targets
  and ports are in the private file. Both are under review for
  necessity and tunnel redundancy.

## Remaining gaps

1. SSID sprawl on main (4 SSIDs, one network).
2. Cilium LB pool is the whole `/21` (collision risk with DHCP/statics).
3. Second port-forward exposure still to review.
4. No IaC or backup record for UniFi config.
