# K3s namespace layout

## Goal

Create a clean namespace split so the observability platform is easy to reason about and secure by default.

## Suggested namespaces

- `observability` — Grafana, Prometheus, Mimir, Loki, Tempo, and related platform config
- `awx` — AWX operator resources, AWX instance objects, and supporting stateful components
- `storage` — Garage S3 and any storage-specific support objects
- `ingress` — only if ingress-specific policy objects need their own namespace

## Namespace rules

- Keep platform services separate from system namespaces.
- Avoid mixing AWX with observability workloads in the same namespace.
- Prefer one namespace per operational boundary rather than one namespace per pod.

## Verification

- `kubectl get ns` shows the expected namespaces.
- Workloads are created in the intended namespace.
- RBAC and network policy decisions can target whole namespaces cleanly.
