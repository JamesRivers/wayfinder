# Deployment scaffold

This folder will hold the actual K3s deployment assets for the observability stack.

Current structure:
- `k8s/` — Kubernetes deployment assets and component overlays
- `scripts/` — validation helpers for the deployment scaffold

Planned component areas:
- `k8s/base/` — shared namespaces and common cluster primitives
- `k8s/storage/garage/` — Garage S3 deployment assets
- `k8s/observability/` — Grafana, Prometheus, Mimir, Loki, Tempo assets
- `k8s/awx/` — AWX operator and instance assets
- `k8s/ai/` — read-only AI boundary assets and MCP contracts
