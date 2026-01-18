<div align="center">

<img src="https://avatars.githubusercontent.com/u/5921618?v=4" alt="logo" align="center" width="175px" height="175px"/>

### 🚀 Home Operations Repository 🚧

_... managed with Flux, Renovate, and GitHub Actions_ 🤖

![Talos](https://kromgo.chezlawrence.com/talos_version?format=badge)
![Kubernetes](https://kromgo.chezlawrence.com/kubernetes_version?format=badge)
![Cluster Age](https://kromgo.chezlawrence.com/cluster_age_days?format=badge)
![Uptime](https://kromgo.chezlawrence.com/cluster_uptime_days?format=badge)
![Nodes](https://kromgo.chezlawrence.com/cluster_node_count?format=badge)
![CPU Usage](https://kromgo.chezlawrence.com/cluster_cpu_usage?format=badge)
![Memory](https://kromgo.chezlawrence.com/cluster_memory_usage?format=badge)
![Pods Running](https://kromgo.chezlawrence.com/cluster_pod_count?format=badge)
![Power](https://kromgo.chezlawrence.com/cluster_power_usage?format=badge)
</div>

---

## 💡 Overview

This is a mono repository for my home infrastructure and Kubernetes cluster. I strive to adhere to **Environment as Code (EaC)**, **Infrastructure as Code (IaC)**, and **GitOps** principles using tools like [Kubernetes](https://kubernetes.io/), [Flux](https://github.com/fluxcd/flux2), [Renovate](https://github.com/renovatebot/renovate), [Talos](https://www.talos.dev/), and [GitHub Actions](https://github.com/features/actions).

The cluster is built on commodity hardware and runs a variety of self-hosted applications for media, networking, observability, and more. All infrastructure and application deployments are version-controlled and automatically synchronized via GitOps.

The cluster is gratuitous overkill for what is actually needed to run the applications that I do. However, it's
fun for me to do stuff like this and the cluster is resilient and fairly low maintenance.

---

## 🌱 Kubernetes

My Kubernetes cluster is deployed with [Talos](https://www.talos.dev/), a minimal, immutable Linux distribution purpose-built for Kubernetes. This is a semi-hyper-converged cluster where workloads and block storage share the same resources on compute nodes, while a separate NAS provides network storage, backups, and additional capacity.

### Core Components

- **[Cilium](https://github.com/cilium/cilium)** - eBPF-based networking and network policies
- **[Cert-Manager](https://github.com/cert-manager/cert-manager)** - Automatic SSL/TLS certificate management
- **[External DNS](https://github.com/kubernetes-sigs/external-dns)** - Automatic DNS record synchronization
- **[External Secrets](https://github.com/external-secrets/external-secrets)** - Kubernetes secret management with external providers
- **[Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)** - Secure access to internal services
- **[Rook Ceph](https://github.com/rook/rook)** - Distributed block storage for persistent volumes
- **[Spegel](https://github.com/spegel-org/spegel)** - Stateless cluster-local OCI registry mirror
- **[Volsync](https://github.com/backube/volsync)** - Automated backup and recovery of persistent volumes
- **[Metrics Server](https://github.com/kubernetes-sigs/metrics-server)** - Resource metrics collection

### GitOps Workflow

[Flux](https://github.com/fluxcd/flux2) watches the `kubernetes/` directory in this repository and automatically applies all declared state to the cluster. The structure follows a pattern where:

1. Top-level `kustomization.yaml` files define namespaces and application deployments
2. Individual application directories contain `HelmRelease` resources and configuration
3. [Renovate](https://github.com/renovatebot/renovate) automatically creates pull requests for dependency updates
4. When PRs are merged, Flux applies the changes automatically

### Directory Structure

```text
kubernetes/
├── apps/           # Application deployments organized by namespace
├── components/     # Reusable Kustomize components
├── flux/           # Flux system configuration and metadata
└── bootstrap/      # Bootstrap procedures and initial setup
```

### Applications

The cluster runs a diverse set of applications:

- **Media**: Plex, Radarr, Sonarr, Lidarr, Calibre-Web, Pinchflat, Tautulli
- **Database**: CloudNative PG, Dragonfly, LLDAP, pgAdmin
- **Download**: qBittorrent, SABnzbd
- **Home Automation**: Mosquitto, Zigbee2MQTT, Z-Wave JS UI
- **Observability**: Gatus, Prometheus, Alertmanager
- **Networking**: Envoy Gateway, K8s Gateway, Cloudflare Tunnel
- **Self-Hosted Tools**: Atuin, Manyfold, Paperless, Syncthing, Tandoor
- **LLM**: Ollama, Open WebUI
- **Gaming**: Epic Games Free Games, ROMM

---

## 🌐 Networking

### VLANs

| VLAN | ID | CIDR | Purpose |
| --- | --- | --- | --- |
| Default | 1 | 192.168.0.0/21 | General-purpose devices |
| Default | 1 | 192.168.12.0/24 | IoT devices |
| Default | 1 | 10.30.0.0/16 | Storage Network |

### DNS

Three instances of [ExternalDNS](https://github.com/kubernetes-sigs/external-dns) provide DNS services:

1. **Cloudflare** - Syncs public DNS records for external access
2. **Pi-Hole** - Internal DNS with local overrides and adblocking
3. **Docker (on existing Proxmox cluster)** - Standalone Pi-Hole for cluster bootstrapping

DNS is divided into two gateways:

- **Internal** - Only exposed to internal network
- **External** - Exposed internally and externally via Cloudflare

---

## ☁️ Cloud Dependencies

While most infrastructure is self-hosted, key services rely on cloud providers for reliability and redundancy:

| Service | Purpose | Cost |
| --------- | --------- | ------ |
| 1Password Secrets Manager | Secret management with External Secrets | ~$70/year$ |
| Cloudflare | Domain and tunnel hosting | Free |
| GitHub | Repository hosting, CI/CD workflows | Free |
| AWS Route53 | Domain registration | ~$15/yr |
| AWS SES | Email service | ~$1/yr |
| Pushover | Alert notifications | $5 OTP |
| **Total** | | **~$86/yr** |

---

## 🖥️ Hardware

### Kubernetes Cluster

| Count | Model | CPU | RAM | Storage | OS | Purpose |
| ------- | ------- | ----- | ----- | --------- | ---- | ---- |
| 5 | MINISFORUM MS-01 | i5-12600H | 96GB DDR4 | 512GB NVMe + 2TB NVMe | Talos | Kubernetes nodes |

### Storage & Management

| Count | Model | CPU | RAM | Storage | OS | Purpose |
| ------- | ------- | ----- | ----- | --------- | ---- | ---- |
| 1 | NAS (custom-built) | Ryzen 5 5600G | 64GB DDR4 | 2x960GB NVME + 5×18TB | Proxmox | Backups, NFS, SMB shares |
| 1 | PiKVM V4 Plus | Raspberry Pi CM4 | 2GB | 16GB SD | PiKVM | KVM |

### Network Hardware

- Multiple managed switches with VLAN support (mostly UniFi)
- Cloudflare Tunnel for secure external access (no port forwarding)
- Pi-Hole for internal DNS and ad-blocking

---

## 🚀 Getting Started

### Prerequisites

- Linux or macOS
- [Talos CLI](https://www.talos.dev/latest/introduction/getting-started/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Flux CLI](https://fluxcd.io/flux/installation/)
- [Helm](https://helm.sh/) (optional)
- [Task](https://taskfile.dev/) (recommended, used in Taskfile.yaml)

### Bootstrap Process

See [bootstrap/](bootstrap/) directory for cluster initialization steps.

---

## 🔐 Security

- **GitOps** - All changes tracked in version control
- **Sealed Secrets / External Secrets** - Secrets encrypted or managed externally
- **Network Policies** - Cilium enforces network segmentation
- **RBAC** - Kubernetes RBAC and pod security policies
- **Immutable OS** - Talos provides an immutable, hardened Linux base

---

## 📊 Monitoring & Observability

The cluster includes:

- **Prometheus** - Metrics collection and alerting
- **Gatus** - Application and endpoint uptime monitoring
- **Alertmanager** - Alert aggregation and routing
- **Pushover** - Mobile notifications for critical alerts

---

## 🙏 Thanks

Special thanks to:

- **[onedr0p](https://github.com/onedr0p)** - For the excellent [cluster-template](https://github.com/onedr0p/cluster-template) and [home-ops](https://github.com/onedr0p/home-ops) repositories
- **[Home Operations Community](https://discord.gg/home-operations)** - Invaluable support, ideas, and inspiration
- **[kubesearch.dev](https://kubesearch.dev/)** - Excellent resource for Kubernetes information and where I basically steal everything from to implement on this cluster.

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).

---

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Talos Documentation](https://www.talos.dev/)
- [Flux Documentation](https://fluxcd.io/)
- [Home Operations Discord](https://discord.gg/home-operations)
- [Renovate Documentation](https://docs.renovatebot.com/)
