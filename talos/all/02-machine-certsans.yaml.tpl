# Machine certSANs (from talconfig additionalMachineCertSans).
# The domain stays SOPS-encrypted in topf.yaml data: — never write it here.
machine:
  certSANs:
    - "127.0.0.1"
    - "192.168.6.0"
    - "{{ .Data.controlPlaneSAN }}"
