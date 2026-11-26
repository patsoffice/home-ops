# Virtual machines — VNC access

How to reach a VM's display (e.g. the Windows installer) with `virtctl`.

## 1. Open the VNC proxy

`virtctl` is provided by the repo tooling: [mise](../../../../.mise.toml)
on macOS, `nix-shell` on Linux. Both set `KUBECONFIG` for you.

```bash
virtctl vnc win11 -n default --proxy-only
```

It prints the port as JSON, e.g. `{"port":60389}`, followed by
`portforward` log lines. Note the port — a fresh one is picked on
every run — and keep that terminal open: closing it kills the proxy.
`connection timeout: 1m0s` is just its idle-timeout notice, and
`VNC Client connected` confirms your viewer reached the proxy.

## 2. Connect a viewer

There is no VNC password. The server offers no authentication;
access control is Kubernetes RBAC via your kubeconfig.

### macOS

Install TigerVNC Viewer and connect to the proxy port:

```bash
brew install --cask tigervnc-viewer
```

In the viewer, enter the server exactly as `127.0.0.1::<port>`
with **two** colons, e.g. `127.0.0.1::60389`. A single colon means
a display number and will not connect, and a `vnc://` prefix breaks
parsing — leave it off.

Do not use the built-in Screen Sharing app: it prompts for a VNC
password that does not exist.

### Linux (nix-shell)

Enter the repo shell (`nix-shell` from the repo root, `virtctl` is
included) and open the same proxy as above. For the viewer, either:

```bash
nix-shell -p tigervnc --run 'vncviewer 127.0.0.1::<port>'
```

with the same double-colon syntax as macOS, or, with
`nix-shell -p virt-viewer`, skip the proxy entirely — plain
`virtctl vnc win11 -n default` launches `remote-viewer` directly.

## 3. If it does not connect

| Symptom | Cause | Fix |
| --- | --- | --- |
| Connection refused / viewer finds nothing | Proxy terminal closed, or port from an older run | Re-run the proxy, use its current port |
| `no route to host` for `192.168.6.0` | Mac is off the LAN | Bring up WireGuard to `wg.chezlawrence.com` first |
| Password prompt | Viewer quirk (Screen Sharing) or stale port | Use TigerVNC with the `::<port>` form |

To confirm the chain independently of any viewer, expect the
`RFB 003.008` banner here (hangs or errors mean the VM side,
not the viewer, is at fault):

```bash
curl -m8 -v telnet://127.0.0.1::<port>
```

A serial console is also available, though Windows setup does not
write to it: `virtctl console win11 -n default`.
