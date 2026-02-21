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
