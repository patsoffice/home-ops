# Envoy Gateway

## Operations

- After any envoy-gateway chart upgrade, roll the data-plane proxy
  deployments (`envoy-external`, `envoy-internal`). A stuck EDS snapshot
  makes running proxies dial dead pod IPs indefinitely; restarts are the
  only recovery (see home-ops-ypg, envoy-gateway v1.7.3 → v1.8.0).
- Passive outlier detection lives in `BackendTrafficPolicy/envoy`
  (`healthCheck.passive`). It ejects an endpoint after 5 consecutive
  connect failures or 5 consecutive 5xx (10s interval, 30s base
  ejection, up to 100%), so a fully stale cluster fails fast with 503s
  instead of hanging. Add any new gateway-wide backend settings to that
  same policy: Envoy Gateway attaches only the oldest BackendTrafficPolicy
  per Gateway and marks the others `Conflicted`; they don't merge.
- Do not change `provider.kubernetes.deploy.type` away from
  `GatewayNamespace`: renaming the managed gateway LB Services drops
  their Cilium L2 announcements and blackholes `.6.202`/`.6.203`.
