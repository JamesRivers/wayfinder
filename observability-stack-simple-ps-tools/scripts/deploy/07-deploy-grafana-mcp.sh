#!/usr/bin/env bash
# ==============================================================================
# 07-deploy-grafana-mcp.sh — Deploy Grafana MCP sidecar (optional)
#
# Usage: bash 07-deploy-grafana-mcp.sh [REPO_DIR]
#
# What this does:
#   1. Deploys the Grafana MCP sidecar via kustomize
#   2. Waits for the pod to be ready
#   3. Verifies the service is accessible
#
# Prerequisites: K3s + Grafana running (03 completed)
# This is optional — the observability stack works without it.
# ==============================================================================
set -euo pipefail

# --- Configuration -----------------------------------------------------------
REPO_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
AI_DEPLOY="${REPO_DIR}/deploy/k8s/ai"
NAMESPACE="ai"

# --- Colours ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step() { echo -e "\n${YELLOW}>>> $*${NC}"; }

# --- Pre-flight checks -------------------------------------------------------
step "Pre-flight checks"

if ! kubectl get nodes &>/dev/null; then
    err "kubectl cannot reach the cluster. Is K3s running?"
    exit 1
fi

if [[ ! -d "${AI_DEPLOY}" ]]; then
    err "AI deploy directory not found: ${AI_DEPLOY}"
    exit 1
fi

log "Cluster reachable, deploy directory found"

# --- Create MCP auth secret ---------------------------------------------------
step "Creating MCP auth secret"

if kubectl get secret -n "${NAMESPACE}" grafana-mcp-auth &>/dev/null; then
    log "Secret grafana-mcp-auth already exists"
else
    # Generate a random server token
    SERVER_TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    kubectl create secret generic grafana-mcp-auth \
        --namespace="${NAMESPACE}" \
        --from-literal=server-token="${SERVER_TOKEN}"
    log "Secret grafana-mcp-auth created"
fi

# --- Deploy -------------------------------------------------------------------
step "Deploying Grafana MCP sidecar to namespace '${NAMESPACE}'"

kubectl apply -k "${AI_DEPLOY}"

log "MCP manifests applied"

# --- Create external NodePort service ----------------------------------------
step "Exposing MCP externally on NodePort 30800"

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: grafana-mcp-external
  namespace: ${NAMESPACE}
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: grafana-mcp
  ports:
    - port: 8000
      targetPort: 8000
      nodePort: 30800
EOF

log "MCP exposed on port 30800"

# --- Wait for pod to be ready ------------------------------------------------
step "Waiting for MCP pod to be ready (up to 120s)"

kubectl rollout status deployment/grafana-mcp -n "${NAMESPACE}" --timeout=120s

log "Grafana MCP pod is ready"

# --- Verification -------------------------------------------------------------
step "Verification"

echo ""
echo "Pods:"
kubectl get pods -n "${NAMESPACE}"

echo ""
echo "Services:"
kubectl get svc -n "${NAMESPACE}"

echo ""
log "Grafana MCP deployment complete"

HOST_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
MCP_TOKEN=$(kubectl get secret -n "${NAMESPACE}" grafana-mcp-auth -o jsonpath='{.data.server-token}' | base64 -d)

echo ""
echo "  MCP internal:  http://grafana-mcp.ai.svc.cluster.local:8000"
echo "  MCP external:  http://${HOST_IP}:30800/mcp"
echo "  Server token:  ${MCP_TOKEN}"
echo ""
echo "  MCP client config (Claude Code / Unsloth / etc.):"
echo "  {"
echo "    \"mcpServers\": {"
echo "      \"grafana\": {"
echo "        \"url\": \"http://${HOST_IP}:30800/mcp\","
echo "        \"headers\": {"
echo "          \"Authorization\": \"Bearer ${MCP_TOKEN}\""
echo "        }"
echo "      }"
echo "    }"
echo "  }"
