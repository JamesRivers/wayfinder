#!/usr/bin/env bash
# ==============================================================================
# 08-show-access-details.sh — Show URLs, usernames, passwords, and endpoints
#
# Usage: bash 08-show-access-details.sh
#
# What this does:
#   1. Detects the host IP and live K3s access method
#   2. Reads AWX and Grafana access details from the running cluster
#   3. Shows Alloy write endpoints and optional Grafana MCP details
#   4. Prints a copy/paste summary for the user
#
# Prerequisites: Run on the observability host after the stack is deployed.
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step() { echo -e "\n${YELLOW}>>> $*${NC}"; }

kcmd() {
    if kubectl version --client >/dev/null 2>&1 && kubectl get namespace default >/dev/null 2>&1; then
        kubectl "$@"
        return 0
    fi

    if command -v sudo >/dev/null 2>&1 && sudo k3s kubectl get namespace default >/dev/null 2>&1; then
        sudo k3s kubectl "$@"
        return 0
    fi

    err "Could not access Kubernetes via kubectl or sudo k3s kubectl"
    return 1
}

jsonpath_or_blank() {
    local resource="$1"
    local expr="$2"
    kcmd get ${resource} -o "jsonpath=${expr}" 2>/dev/null || true
}

deployment_env_value() {
    local namespace="$1"
    local deployment="$2"
    local env_name="$3"

    python3 - "$namespace" "$deployment" "$env_name" <<'PY'
import json, subprocess, sys
ns, dep, env_name = sys.argv[1:4]
cmd = ["kubectl", "get", "deploy", "-n", ns, dep, "-o", "json"]
try:
    raw = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)
except Exception:
    cmd = ["sudo", "k3s", "kubectl", "get", "deploy", "-n", ns, dep, "-o", "json"]
    raw = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)
data = json.loads(raw)
for container in data.get("spec", {}).get("template", {}).get("spec", {}).get("containers", []):
    for env in container.get("env", []):
        if env.get("name") == env_name:
            print(env.get("value", ""))
            raise SystemExit(0)
print("")
PY
}

step "Pre-flight checks"
kcmd get nodes >/dev/null
log "Cluster reachable"

HOST_IP="$(jsonpath_or_blank 'nodes' '{.items[0].status.addresses[?(@.type=="InternalIP")].address}')"
if [[ -z "${HOST_IP}" ]]; then
    err "Could not determine host IP from the cluster"
    exit 1
fi

AWX_USER="admin"
AWX_PASS="$(jsonpath_or_blank 'secret -n awx observability-awx-admin-password' '{.data.password}' | base64 -d 2>/dev/null || true)"
AWX_NODEPORT="$(jsonpath_or_blank 'svc -n awx observability-awx-service' '{.spec.ports[0].nodePort}')"
AWX_NODEPORT="${AWX_NODEPORT:-30080}"
AWX_URL_NODEPORT="http://${HOST_IP}:${AWX_NODEPORT}"
AWX_URL_INGRESS="http://${HOST_IP}/awx"

GRAFANA_USER="$(deployment_env_value observability grafana GF_SECURITY_ADMIN_USER)"
GRAFANA_PASS="$(deployment_env_value observability grafana GF_SECURITY_ADMIN_PASSWORD)"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"
GRAFANA_URL="http://${HOST_IP}/grafana"

MIMIR_WRITE_URL="http://${HOST_IP}/mimir/api/v1/push"
LOKI_WRITE_URL="http://${HOST_IP}/loki/loki/api/v1/push"
PROMETHEUS_URL_INTERNAL="http://prometheus.observability.svc.cluster.local:9090"
TEMPO_URL_INTERNAL="http://tempo.observability.svc.cluster.local:3200"
TEMPO_OTLP_GRPC_INTERNAL="tempo.observability.svc.cluster.local:4317"
TEMPO_OTLP_HTTP_INTERNAL="http://tempo.observability.svc.cluster.local:4318"
GIT_BUNDLE_URL="git://${HOST_IP}:9418/alloy-template-bundle.git"

MCP_DEPLOYED="no"
MCP_URL=""
MCP_TOKEN=""
if kcmd get namespace ai >/dev/null 2>&1; then
    if kcmd get deploy -n ai grafana-mcp >/dev/null 2>&1; then
        MCP_DEPLOYED="yes"
        MCP_URL="http://${HOST_IP}:30800/mcp"
        MCP_TOKEN="$(jsonpath_or_blank 'secret -n ai grafana-mcp-auth' '{.data.server-token}' | base64 -d 2>/dev/null || true)"
    fi
fi

step "Access summary"

echo ""
echo "Host"
echo "  IP: ${HOST_IP}"
echo ""
echo "AWX"
echo "  URL (NodePort): ${AWX_URL_NODEPORT}"
echo "  URL (Ingress):  ${AWX_URL_INGRESS}"
echo "  Username:       ${AWX_USER}"
echo "  Password:       ${AWX_PASS:-NOT_FOUND}"
echo ""
echo "Grafana"
echo "  URL:            ${GRAFANA_URL}"
echo "  Username:       ${GRAFANA_USER}"
echo "  Password:       ${GRAFANA_PASS}"
echo ""
echo "Alloy write endpoints"
echo "  Mimir write:    ${MIMIR_WRITE_URL}"
echo "  Loki write:     ${LOKI_WRITE_URL}"
echo "  Git bundle:     ${GIT_BUNDLE_URL}"
echo ""
echo "Internal-only endpoints"
echo "  Prometheus:     ${PROMETHEUS_URL_INTERNAL}"
echo "  Tempo HTTP:     ${TEMPO_URL_INTERNAL}"
echo "  Tempo OTLP gRPC:${TEMPO_OTLP_GRPC_INTERNAL}"
echo "  Tempo OTLP HTTP:${TEMPO_OTLP_HTTP_INTERNAL}"

echo ""
if [[ "${MCP_DEPLOYED}" == "yes" ]]; then
    echo "Grafana MCP"
    echo "  URL:            ${MCP_URL}"
    echo "  Bearer token:   ${MCP_TOKEN:-NOT_FOUND}"
else
    echo "Grafana MCP"
    echo "  Not deployed"
fi

step "Verification hints"
echo ""
echo "  AWX password cmd:     sudo k3s kubectl get secret -n awx observability-awx-admin-password -o jsonpath='{.data.password}' | base64 -d"
echo "  AWX project list:     curl -s -u ${AWX_USER}:${AWX_PASS:-'<password>'} ${AWX_URL_NODEPORT}/api/v2/projects/"
echo "  Grafana login check:  curl -s -u ${GRAFANA_USER}:${GRAFANA_PASS} ${GRAFANA_URL}/api/user"
echo ""
log "Access details collected"
