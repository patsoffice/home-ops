### A rook-ceph namespace debugging image

To start the DaemonSet:

```sh
kubectl apply -f hack/debug/rook-ceph-ubuntu.yaml
```

To enter the pod, find the pod name:

```sh
kubectl get pods -n rook-ceph -l name=ubuntu-debug -o wide
kubectl -n rook-ceph exec -it ubuntu-debug-XXXX -- bash
```

To delete the DaemonSet when done:

```sh
kubectl delete daemonset -n rook-ceph ubuntu-debug
```
