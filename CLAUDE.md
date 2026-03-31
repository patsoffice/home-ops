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
