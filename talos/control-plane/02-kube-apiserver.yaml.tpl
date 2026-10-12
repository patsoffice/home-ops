# API server config as the typed 1.14 document (replaces legacy
# cluster.apiServer, removed from v1alpha1 in Talos 1.14). Carries the
# apiServer SANs (certExtraSANs), the admission feature gates, the aggregation
# layer routing flag, and the MAP runtime-config folded in from the old
# mutatingadmissionpolicy patch. The domain stays SOPS-encrypted in topf.yaml
# data: — never write it here.
apiVersion: v1alpha1
kind: KubeAPIServerConfig
certExtraSANs:
  - "127.0.0.1"
  - "192.168.6.0"
  - "{{ .Data.controlPlaneSAN }}"
extraArgs:
  feature-gates: ResourceHealthStatus=true,MutatingAdmissionPolicy=true
  # https://kubernetes.io/docs/tasks/extend-kubernetes/configure-aggregation-layer/
  enable-aggregator-routing: true
  runtime-config: admissionregistration.k8s.io/v1alpha1=true,admissionregistration.k8s.io/v1beta1=true
