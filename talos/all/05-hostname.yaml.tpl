# topf does not set the hostname from the node entry (unlike talhelper),
# so it must be patched explicitly. Matches the talhelper-rendered form.
apiVersion: v1alpha1
kind: HostnameConfig
auto: 'off'
hostname: {{ .Node.Host }}
