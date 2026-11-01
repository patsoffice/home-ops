# UniFi read-only access for LLMs

Local LLMs (e.g. Muse Code on a workstation) query the UniFi console
through [scripts/unifi-ro-get.sh](/home/pjl/ws/home-ops/scripts/unifi-ro-get.sh).
The script only sends `GET` requests. It refuses anything else before
touching the network.

The read-only guarantee comes from the UniFi role, not the script.
The script is a second layer.

## What the user sets up

1. Create a dedicated local admin in the UniFi Network app:
   Admins, Add, `Local Access Only`, role `View Only`, all sites.
   Name it `llm-readonly`. Never use the owner account.
2. On Network 10.6, a viewer cannot mint API keys. Key creation is
   hidden for that role. Use the viewer username and password with
   session login instead.
3. Store the credentials in 1Password as `unifi-llm-readonly`
   (username, password). Do not reuse the existing `unifi` item.
   That item holds an admin-minted API key for
   [unpoller](/home/pjl/ws/home-ops/kubernetes/apps/observability/unpoller/app/externalsecret.yaml).
   It can write, so it stays in-cluster only.
4. Prove the role is read-only. Log in, run a read, then attempt a
   harmless write with a fake MAC. The write must return `403`
   (`api.err.NoPermission`). If it returns `ok`, delete the account
   and start over.

## How the user keeps the session alive

The user logs in once. The password stays in the user's shell only.
The LLM never sees it.

```zsh
read -s 'PW?Viewer password: '; curl -sk -c /tmp/unifi.jar \
  -X POST "https://192.168.0.1/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"llm-readonly\",\"password\":\"$PW\"}"; unset PW
chmod 600 /tmp/unifi.jar
```

Repeat when the session expires. The script tells the model to ask
for this with exit code 3.

## How the LLM uses the script

```sh
./scripts/unifi-ro-get.sh "stat/device"
```

No env vars needed. Defaults are the console at
`https://192.168.0.1`, site `default`, jar `/tmp/unifi.jar`.
Override with `UNIFI_HOST`, `UNIFI_SITE`, `UNIFI_JAR`.

Rules for the model:

- Call the script. Never ask for the password.
- Valid paths start with `stat/`, `list/`, or `get/`.
  Examples: `stat/health`, `stat/device`, `list/networkconf`,
  `list/wlanconf`, `list/firewallgroup`.
- The zone-based firewall lives on the v2 API. The script accepts
  exactly these `v2/` paths: `v2/firewall-policies`, `v2/firewall/zone`,
  `v2/firewall/zone-matrix`, `v2/trafficrules`, `v2/trafficroutes`.
  The v1 `list/firewallrule` returns an empty list since the Policy
  Engine upgrade. That does not mean there are no rules.
- `wlanconf` output contains WiFi passphrases. Redact
  `x_passphrase` before quoting it back. `get/setting` includes tokens
  (e.g. `utm_token` in the `ips` key). Filter them out too.
- Some fields are false negatives: `stat/sysinfo` `autobackup` (backups
  are a UniFi OS setting the Network API can't see) and the `vpn`
  health and site-to-site counters (the SD-WAN mesh works anyway).
- On exit 3, the session is dead and only the user can refresh it.
  Say so and stop.
- On `403` for a `GET`, the site name is likely wrong.
- Credentials never touch a file, a doc, or the repo.
  If `UNIFI_USER` / `UNIFI_PASS` are set, the script can refresh
  the session itself. Prefer leaving them unset.

## Limits

- Local network only. Nothing here crosses the WAN.
- Sessions expire. The user re-runs the login step above.
- The console uses a self-signed cert. The script passes `-k`,
  same as the UI. This is expected on LAN.
