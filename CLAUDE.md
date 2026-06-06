# CLAUDE.md

## Project Overview

This is a Kubernetes home-ops GitOps repository managed by Flux CD. It contains Helm releases, Kustomizations, and Talos machine configurations for a homelab cluster.

## Repository Structure

- `kubernetes/apps/` — Application deployments organized by category (media, home, database, etc.)
- `kubernetes/flux/` — Flux CD GitOps configuration and bootstrap
- `kubernetes/components/` — Reusable Kustomize components
- `talos/` — Talos Linux machine configuration and patches

## Key Patterns

- Many apps use HelmRelease with the `bjw-s-labs/helm/app-template` chart via OCIRepository
- Secrets are managed with ExternalSecret pulling from 1Password (ClusterSecretStore: `onepassword`)
- SOPS-encrypted files use `*.sops.yaml` suffix
- Container images use tag + SHA256 digest pinning (e.g., `1.2.3@sha256:...`)
- Renovate annotations in comments track dependency versions (e.g., `# renovate: datasource=docker depName=...`)

## Commit Style

- Prefix: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`
- Summary line under 80 chars with counts where relevant
- Body: each logical change on its own `-` bullet
- Summarize what was added/changed and why, not just file names

## Read-Only Tooling (sak)

`sak` is a strictly read-only "Swiss Army Knife for LLMs" installed on this machine — safe to call freely. Domains: `fs`, `git`, `json`, `config`, `csv`, `cert`, `hash`, `talos`, `gh`, `helm`, `nix`, `k8s`, `lxc`, `docker`, `sqlite`, `prom`, `loki`, `hook`. Run `sak <domain> --help` or `sak <domain> <cmd> --help` for details.

**Whenever a read-only operation is in scope, prefer `sak <domain> <cmd>` over the underlying CLI** (`kubectl`, `helm`, `talosctl`, `gh`, `nix`, `git`, `openssl`, `sha256sum`, `curl + jq`, etc.). Output is concise, deterministic, LLM-shaped, and a PreToolUse hook actively blocks the raw equivalents of several of these. The harness's built-in Read/Glob/Grep tools remain the right call for plain file reads — reach for `sak fs` only for what those don't cover (`largest`, `duplicates`, `find`, `tree`, `stat`, `wc`).

### Substitutions (use the right-hand command, not the left)

- `git status|log|diff|show|blame` → `sak git status|log|diff|show|blame` (raw `git` reads are hook-blocked)
- `kubectl get|describe|logs|events` → `sak k8s get|describe|logs|events|failing|pending|restarts|not-ready|images|env|schema`
- `helm list|status|get|template|lint` → `sak helm list|status|get|history|show|template|lint|search|repo-list|dependency-list`
- `for n in <ips>; do talosctl -n $n read|get …` → `sak talos certs|read|get` (fan-out across all nodes in the active talosconfig)
- `gh pr|issue|run|release view|list` → `sak gh pr-view|issue-view|run-view|release-view|pr-list|issue-list|run-list|release-list|api`
- `nix flake show|store info|eval|registry list` → `sak nix flake-show|store-info|eval|registry-list|profile-list|references|path-info|flake-metadata`
- `curl + jq` vs Prometheus / Alertmanager → `sak prom alerts|query|query-range|histogram|targets|rules|labels|label-values|series|metadata|tsdb-stats|am alerts|am silences`
- `curl + jq` vs Loki → `sak loki query|query-range|labels|label-values|series`
- `openssl x509 | grep|awk` → `sak cert inspect|expiring|from-kubeconfig|from-yaml`
- `sha256sum|sha1sum|md5sum|b3sum` → `sak hash sha256|sha1|md5|blake3` (add `--verify <sumfile>`)
- `cat|head|tail|wc|stat|tree` → `sak fs read|head|tail|wc|stat|tree` (Read still preferred for plain text)
- `find . -size … -mtime …` → `sak fs find . --size +1M --mtime -7d` (also `largest`, `duplicates`)
- `jq` on JSON → `sak json query|select|keys|flatten|paths|grep|schema|diff|validate`
- ad-hoc grep on YAML/TOML/plist → `sak config query|keys|flatten|paths|grep|convert|diff|validate` (HelmRelease, Kustomization, etc.)
- `sqlite3 'SELECT …'` → `sak sqlite tables|schema|count|dump|query|info` (`SELECT`/`WITH`/`EXPLAIN`/`PRAGMA` only)
- `lxc list|info` / `docker ps|logs` → `sak lxc list|info|config|images` / `sak docker list|info|config|images|logs`

### Repo-specific patterns

- **Flux / cluster triage** — `sak k8s not-ready kustomization -A` and `sak k8s not-ready helmrelease -A` are the fastest way to surface broken Flux objects. Pair with `sak k8s failing -A` / `sak k8s pending -A` / `sak k8s restarts -A --min 3` / `sak k8s events -A --limit 30` / `sak k8s describe` / `sak k8s logs <pod> -n <ns> --tail 100 --grep ERROR`.
- **HelmRelease / Kustomization inspection** — `sak config query .spec.values.image.tag <file.yaml>`, `sak config keys --depth 2 --types <file.yaml>`, `sak config flatten` + grep for finding where a value lives, `sak config grep <regex>` for key-or-value regex search.
- **Helm release state in-cluster** — `sak helm list -A`, `sak helm status <release> -n <ns>`, `sak helm get <release> --what manifest|values|notes -n <ns>`, `sak helm history <release> -n <ns>`. For chart-local work: `sak helm template ./chart`, `sak helm lint ./chart` (see gotcha), `sak helm dependency-list ./chart`.
- **GitHub** — `sak gh pr-list --state open`, `sak gh pr-view <num>`, `sak gh run-list --workflow ci.yml`, `sak gh run-view <id> --log-failed`, `sak gh api <endpoint>` as the escape hatch (GET-only).
- **Cluster certificate audit** — `sak talos certs --tsv` for fleet-wide inventory; `sak cert from-kubeconfig ~/.kube/config --ca` for kubeconfig certs; `sak cert expiring --days 30 *.pem` in `if` blocks.
- **Prometheus / Alertmanager / Loki** — `sak prom alerts --firing`, `sak prom targets --down`, `sak prom rules --firing`, `sak prom query 'up == 0'`, `sak loki query '{namespace="flux-system"} |= "error"'`.
- **CRD schema lookup** — `sak k8s schema HelmRelease | sak json keys .properties.spec --depth 2`.

### Exit-code gotchas (two commands invert 0/1)

- `sak cert expiring` — exit 0 = no matches (healthy), exit 1 = at least one match (alert). Drives `if sak cert expiring; then …; fi`.
- `sak helm lint` — exit 0 = chart passes lint, exit 1 = chart fails. Drives `if sak helm lint ./chart; then …; fi`.

Every other sak command follows the standard convention: 0 = results, 1 = no results, 2 = tool error.

### Other gotchas

- **`sak cert from-yaml --path` with dotted keys** — use JSON Pointer (`/data/tls.crt`) not dot notation (`.data.tls.crt`) when a key contains a dot. Kubernetes Secrets are the classic case.
- **`sak talos certs` exit 1 with no output** — suspect an expired *client* cert in `~/.talos/config` before assuming nodes are unreachable. Verify with `sak cert from-yaml ~/.talos/config --path /contexts/<name>/crt --field not_after`.
- **`sak talos read` multi-node mode is not byte-faithful** — use `--node <single-ip>` when piping into `sak cert inspect`.
- **`sak k8s get` emits NDJSON, not a List wrapper** — `--path` is applied per-object; use `.metadata.name`, not `.items[0].metadata.name`. Pipe one line at a time into `sak json`.

`sak` cannot mutate state. For anything that changes the cluster (`kubectl apply`, `flux reconcile`, `helm upgrade`, `git push`) use the real tool and follow the confirmation rules for risky actions. Raw `git` is still required for mutations (`commit`, `push`, `add`, etc.) — the PreToolUse hook only blocks read-only git verbs.

## Issue Tracking (beads)

This project uses `br` (beads_rust) for local issue tracking. Issues live in `.beads/` and are committed to git.

```bash
br list                                        # Show all open issues
br list --status open --priority 0-1 --json    # High-priority open issues (machine-readable)
br ready --json                                # Actionable issues (not blocked, not deferred)
br show <id>                                   # Show issue details
br create "Title" -p 2 --type feature          # Create an issue (types: feature, bug, task, chore)
br update <id> --status in_progress            # Claim work
br close <id> --reason "explanation"           # Close with reason
br dep add <id> <depends-on-id>                # Express dependency
br sync --flush-only                           # Export to JSONL for git commit
```

- **Priority scale**: 0 = critical, 1 = high, 2 = medium, 3 = low, 4 = backlog
- **Statuses**: `open`, `in_progress`, `deferred`, `closed`
- **Labels**: use to categorize by area (`core`, `cli`, `web`, etc.)
- Use `RUST_LOG=error` prefix when parsing `--json` output to suppress log noise
- `br` never auto-commits — run `br sync --flush-only` then commit `.beads/` manually
- Check `br ready --json` at the start of a session to see what's actionable
- Close issues with descriptive `--reason` so context is preserved
