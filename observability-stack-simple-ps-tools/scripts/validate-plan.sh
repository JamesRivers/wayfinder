#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"

printf 'Validating observability stack plan files in %s\n' "$root_dir"

for file in \
  "$root_dir/MAP.md" \
  "$root_dir/.hermes/plans/2026-08-17_112856-observability-stack-k3s-plan.md" \
  "$root_dir/k8s/cluster/install.md" \
  "$root_dir/k8s/cluster/ingress.md" \
  "$root_dir/k8s/cluster/storage.md" \
  "$root_dir/k8s/cluster/namespaces.md" \
  "$root_dir/k8s/storage/garage.md" \
  "$root_dir/k8s/storage/mimir-object-store.md" \
  "$root_dir/k8s/storage/tempo-object-store.md" \
  "$root_dir/k8s/observability/grafana.md" \
  "$root_dir/k8s/observability/prometheus.md" \
  "$root_dir/k8s/observability/mimir.md" \
  "$root_dir/k8s/observability/loki.md" \
  "$root_dir/k8s/observability/tempo.md" \
  "$root_dir/k8s/awx/awx-operator.md" \
  "$root_dir/k8s/awx/awx-instance.md" \
  "$root_dir/k8s/awx/alloy-playbooks.md" \
  "$root_dir/k8s/awx/inventory-model.md" \
  "$root_dir/deploy/k8s/awx/namespace.yaml" \
  "$root_dir/deploy/k8s/awx/kustomization.yaml" \
  "$root_dir/deploy/k8s/awx/awx.yaml" \
  "$root_dir/deploy/k8s/awx/README.md" \
  "$root_dir/ai/mcp/interface.md" \
  "$root_dir/ai/skills/topology.md" \
  "$root_dir/ai/skills/ecosystem.md" \
  "$root_dir/ai/skills/rca-playbooks.md" \
  "$root_dir/ai/skills/query-patterns.md" \
  "$root_dir/deploy/README.md" \
  "$root_dir/deploy/k8s/README.md" \
  "$root_dir/deploy/k8s/base/README.md" \
  "$root_dir/deploy/k8s/base/namespaces.yaml" \
  "$root_dir/deploy/k8s/storage/garage/README.md" \
  "$root_dir/deploy/k8s/storage/garage/namespace.yaml" \
  "$root_dir/deploy/k8s/storage/garage/garage.toml" \
  "$root_dir/deploy/k8s/storage/garage/bootstrap.env" \
  "$root_dir/deploy/k8s/storage/garage/kustomization.yaml" \
  "$root_dir/deploy/k8s/storage/garage/service.yaml" \
  "$root_dir/deploy/k8s/storage/garage/statefulset.yaml" \
  "$root_dir/deploy/k8s/observability/README.md" \
  "$root_dir/deploy/k8s/observability/grafana-datasources.yaml" \
  "$root_dir/deploy/k8s/observability/tempo-config.yaml" \
  "$root_dir/deploy/k8s/observability/tempo-pvc.yaml" \
  "$root_dir/deploy/k8s/observability/tempo-deployment.yaml" \
  "$root_dir/deploy/k8s/observability/tempo-service.yaml" \
  "$root_dir/deploy/k8s/observability/loki-config.yaml" \
  "$root_dir/deploy/k8s/observability/loki-pvc.yaml" \
  "$root_dir/deploy/k8s/observability/loki-deployment.yaml" \
  "$root_dir/deploy/k8s/observability/loki-service.yaml" \
  "$root_dir/deploy/k8s/ai/README.md" \
  "$root_dir/deploy/k8s/ai/kustomization.yaml" \
  "$root_dir/deploy/k8s/ai/grafana-mcp/README.md" \
  "$root_dir/deploy/k8s/ai/grafana-mcp/namespace.yaml" \
  "$root_dir/deploy/k8s/ai/grafana-mcp/kustomization.yaml" \
  "$root_dir/deploy/k8s/ai/grafana-mcp/deployment.yaml" \
  "$root_dir/deploy/k8s/ai/grafana-mcp/service.yaml" \
  "$root_dir/scripts/bootstrap-grafana-mcp.sh"; do
  if [[ ! -f "$file" ]]; then
    printf 'Missing required file: %s\n' "$file" >&2
    exit 1
  fi
done

printf 'All required plan files are present.\n'