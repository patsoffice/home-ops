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

`sak` is a strictly read-only "Swiss Army Knife for LLMs" installed on this machine — safe to call freely. Run `sak <domain> --help` or `sak <domain> <cmd> --help` for details. Domains: `fs`, `git`, `json`, `config`, `csv`, `cert`, `talos`, `k8s`, `lxc`, `docker`, `sqlite`, `prom`.

**Prefer `sak` over hand-rolled `kubectl` for live-cluster triage** — output is concise and composable:

- `sak k8s failing -A` / `sak k8s pending -A` — pods not Running/Succeeded, pods stuck Pending
- `sak k8s restarts -A --min 3` — crash-looping containers
- `sak k8s events -A --limit 30` / `sak k8s events --for deploy/foo -n bar` — recent events
- `sak k8s describe <kind> <name> -n <ns>` — aggregated object/status/containers/owners/events
- `sak k8s logs <pod> -n <ns> --tail 100 --grep ERROR` (also `--since 10m`, `-c`, `--all-containers`, `-p`)
- `sak k8s get <kind> [name] -A --path .spec.replicas` — list/get with optional field extraction
- `sak k8s images [kind] -A` — audit container images (default kind: pods)
- `sak k8s schema <Kind>` — OpenAPI v3 schema (pipe through `sak json keys/query`)

**Prefer `sak config` over ad-hoc grep for YAML manifests** (HelmRelease, Kustomization, etc.) — auto-detects TOML/YAML/plist:

- `sak config query .spec.values.image.tag <file.yaml>` — extract a value
- `sak config keys --depth 2 --types <file.yaml>` — explore structure
- `sak config flatten <file.yaml>` — `path<TAB>value` for grep-friendly search
- `sak config grep <regex> <file.yaml>` — find paths whose key or value matches
- `sak config convert --to json <file.yaml>` — convert between TOML/YAML/plist/JSON
- `sak config diff <a.yaml> <b.yaml>` — structural diff (cross-format)
- `sak config validate <file.yaml>` — syntax check

**`sak json`** (`query`, `select`, `keys`, `flatten`, `paths`, `grep`, `schema`, `diff`, `validate`) chains nicely after `sak k8s get --path` or `sak k8s schema`. Use `select` to project a few fields, `paths` to enumerate leaf paths, `grep` to find paths by key/value regex.

**`sak csv`** (`headers`, `query`, `stats`, `validate`) for delimited data:

- `sak csv headers <file.csv>` — list column names and indices
- `sak csv query -c name,age <file.csv>` — project columns and filter rows
- `sak csv stats <file.csv>` — per-column summary statistics
- `sak csv validate <file.csv>` — structure / parse-error check

**`sak sqlite`** (`tables`, `schema`, `info`, `count`, `dump`, `query`) is read-only and only accepts `SELECT` / `WITH` / `EXPLAIN` / `PRAGMA` — safe for poking at app databases.

**`sak cert`** parses X.509 certs from PEM, DER, base64-wrapped PEM (Kubernetes Secret shape), or stdin:

- `sak cert inspect <file>` / `sak cert inspect --field not_after <file>` — full or single-field
- `sak cert from-kubeconfig ~/.kube/config [--ca]` — walk a kubeconfig's client (and optional CA) certs
- `sak cert from-yaml <file> --path /data/tls.crt` — extract+inspect a cert at a YAML path (use JSON Pointer when keys contain dots, like `tls.crt`)
- `sak cert expiring --days 30 <file>` — **exit codes are inverted vs. other sak commands**: 0 = no matches (healthy), 1 = at least one match (alert). Drives `if sak cert expiring; then …; fi`.

**`sak talos`** is the read-only `talosctl` wrapper for the homelab cluster:

- `sak talos certs` — fan-out cert inventory across every node in the active talosconfig (the killer feature; pair with `--tsv` or `--field not_after` for audits)
- `sak talos read <path>` — `talosctl read` across nodes; **use `--node <ip>` for byte-faithful single-node output** when piping into `sak cert inspect`
- `sak talos get <resource> [name]` — COSI resources (`members`, `services`, `mounts`, ...)
- If `sak talos certs` exits 1 with no output, suspect an expired *client* cert in `~/.talos/config` before assuming nodes are unreachable — check with `sak cert from-yaml ~/.talos/config --path /contexts/<name>/crt --field not_after`.

**`sak prom`** hits the Prometheus / Alertmanager HTTP APIs (env vars `PROMETHEUS_URL` and `ALERTMANAGER_URL`, overridable with `--url`):

- `sak prom alerts [--firing|--pending|--all] [--name REGEX]`
- `sak prom targets [--down] [--job REGEX]`, `sak prom rules [--firing]`
- `sak prom query '<promql>'`, `sak prom query-range '<promql>' --since 1h --step 1m`
- `sak prom histogram <metric>` — auto-detects unit from metric name (`_seconds`→duration, `_bytes`→bytes)
- `sak prom am alerts` / `sak prom am silences` — Alertmanager state

**Always use `sak git` instead of raw `git`** for read-only inspection (`status`, `diff`, `log`, `show`, `blame`, `branch`, `tags`, `remote`, `stash-list`, `contributors`). A PreToolUse hook blocks raw `git` read commands. Raw `git` is still required for mutations (`commit`, `push`, `add`, etc.) since `sak` is read-only.

**Do not reach for `sak fs`** — the built-in Read/Glob/Grep are faster and better integrated. Use `sak fs` only when piping into other `sak` commands.

`sak` cannot mutate state. For anything that changes the cluster (`kubectl apply`, `flux reconcile`, `helm upgrade`, `git push`) use the real tool and follow the confirmation rules for risky actions.

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
