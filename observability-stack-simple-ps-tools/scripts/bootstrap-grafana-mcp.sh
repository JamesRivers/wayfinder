#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
namespace="ai"
secret_name="grafana-mcp-auth"

token="${GRAFANA_MCP_SERVER_TOKEN:-}"
if [[ -z "$token" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    token="$(openssl rand -hex 32)"
  else
    token="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
)"
  fi
fi

kubectl apply -f "$root_dir/deploy/k8s/ai/grafana-mcp/namespace.yaml"

kubectl -n "$namespace" create secret generic "$secret_name" \
  --from-literal=server-token="$token" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -k "$root_dir/deploy/k8s/ai"

kubectl -n "$namespace" rollout status deploy/grafana-mcp --timeout=300s
kubectl -n "$namespace" get pods -o wide
