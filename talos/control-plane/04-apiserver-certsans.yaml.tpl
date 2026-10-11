# API server certSANs (from talconfig additionalApiServerCertSans).
# topf has no equivalent field, so the full list is patched explicitly.
# The domain stays SOPS-encrypted in topf.yaml data: — never write it here.
cluster:
  apiServer:
    certSANs:
      - "127.0.0.1"
      - "192.168.6.0"
      - "{{ .Data.controlPlaneSAN }}"
