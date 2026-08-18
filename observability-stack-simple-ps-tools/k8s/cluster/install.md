# K3s cluster bootstrap

## Goal

Stand up a single-node K3s cluster on the observability host so the platform services can run inside Kubernetes while remaining simple to operate.

## Target host

- Target host: `172.16.47.163`
- Host role: single observability hub node

## Access path

- Use the jump host chain only when needed for reachability: `ssh -J imagine@100.102.149.18 imagine@172.16.47.163`

## Installation posture

Use the K3s server install on the host itself. Keep the cluster intentionally single-node for the first version.

### High-level install shape

- Install K3s server on the hub node.
- Disable any bundled components we do not want to rely on implicitly if they conflict with the planned ingress or storage choices.
- Keep the cluster networking simple and predictable.
- Prepare namespaces and storage before the observability workloads land.

## Operational assumptions

- One control-plane node only.
- No separate worker pool for the first version.
- Ingress and observability workloads share the same cluster.
- External AI remains outside the cluster and only consumes read-only interfaces.

## Verification

- `kubectl get nodes` shows one Ready node.
- `kubectl get pods -A` shows the system pods healthy.
- `kubectl get storageclass` shows the expected default storage class.
