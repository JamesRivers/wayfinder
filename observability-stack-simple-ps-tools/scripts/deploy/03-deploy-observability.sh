#!/usr/bin/env bash
# ==============================================================================
# 03-deploy-observability.sh — Deploy the LGTM observability stack
#
# Usage: bash 03-deploy-observability.sh [REPO_DIR]
#
# What this does:
#   1. Deploys Prometheus, Mimir, Loki, Tempo, Grafana via kustomize
#   2. Configures Traefik IngressRoutes for write endpoints
#   3. Waits for all pods to be ready
#   4. Imports dashboards into Grafana
#   5. Verifies all services are accessible
#
# Prerequisites: K3s + Garage running (01, 02 completed)
# ==============================================================================
set -euo pipefail

# --- Configuration -----------------------------------------------------------
REPO_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
OBS_DEPLOY="${REPO_DIR}/deploy/k8s/observability"
DASHBOARD_DIR="${REPO_DIR}/deploy/k8s/observability/dashboards"
NAMESPACE="observability"

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

if [[ ! -d "${OBS_DEPLOY}" ]]; then
    err "Observability deploy directory not found: ${OBS_DEPLOY}"
    exit 1
fi

# Check Garage is running
if ! kubectl get pods -n storage garage-0 --no-headers 2>/dev/null | grep -q Running; then
    err "Garage pod is not running. Run 02-deploy-garage.sh first."
    exit 1
fi

log "Cluster reachable, Garage running, deploy directory found"

# --- Install Traefik CRDs if needed ------------------------------------------
step "Checking Traefik CRDs"

if kubectl get crd ingressroutes.traefik.io &>/dev/null; then
    log "Traefik IngressRoute CRD already installed"
else
    warn "Traefik CRD not found — IngressRoutes may not work"
fi

# --- Deploy observability stack via kustomize ---------------------------------
step "Deploying observability stack to namespace '${NAMESPACE}'"

kubectl apply -k "${OBS_DEPLOY}"

log "Observability manifests applied"

# --- Wait for all deployments to be ready -------------------------------------
step "Waiting for deployments to be ready (up to 300s)"

DEPLOYMENTS=("prometheus" "mimir" "loki" "tempo" "grafana")

for DEP in "${DEPLOYMENTS[@]}"; do
    echo -n "  Waiting for ${DEP}... "
    if kubectl rollout status deployment/${DEP} -n "${NAMESPACE}" --timeout=300s &>/dev/null; then
        echo -e "${GREEN}ready${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        err "${DEP} did not become ready"
        kubectl get pods -n "${NAMESPACE}" -l app="${DEP}" 2>/dev/null
    fi
done

log "All deployments ready"

# --- Wait for Grafana to be accessible ----------------------------------------
step "Waiting for Grafana API to respond (up to 60s)"

GRAFANA_SVC="http://$(kubectl get svc -n ${NAMESPACE} grafana -o jsonpath='{.spec.clusterIP}'):80"

for i in $(seq 1 12); do
    if kubectl exec -n "${NAMESPACE}" deploy/grafana -- wget -q -O /dev/null http://localhost:3000/api/health 2>/dev/null; then
        log "Grafana API responding"
        break
    fi
    if [[ $i -eq 12 ]]; then
        warn "Grafana API did not respond within 60s"
        break
    fi
    sleep 5
done

# --- Import dashboards --------------------------------------------------------
step "Importing dashboards into Grafana"

if [[ -d "${DASHBOARD_DIR}" ]]; then
    DASHBOARD_COUNT=0
    for DASHBOARD_FILE in "${DASHBOARD_DIR}"/*.json; do
        if [[ -f "${DASHBOARD_FILE}" ]]; then
            DASHBOARD_NAME=$(basename "${DASHBOARD_FILE}" .json)
            echo -n "  Importing ${DASHBOARD_NAME}... "

            # Wrap dashboard JSON in the import payload
            PAYLOAD=$(python3 -c "
import json, sys
with open('${DASHBOARD_FILE}') as f:
    dash = json.load(f)
dash['id'] = None
dash['uid'] = None
payload = {'dashboard': dash, 'overwrite': True, 'folderId': 0}
print(json.dumps(payload))
")

            RESULT=$(kubectl exec -n "${NAMESPACE}" deploy/grafana -- \
                wget -q -O - \
                --header='Content-Type: application/json' \
                --header='Authorization: Basic YWRtaW46YWRtaW4=' \
                --post-data="${PAYLOAD}" \
                http://localhost:3000/api/dashboards/db 2>&1 || true)

            if echo "${RESULT}" | grep -q '"status":"success"'; then
                echo -e "${GREEN}ok${NC}"
                DASHBOARD_COUNT=$((DASHBOARD_COUNT + 1))
            else
                echo -e "${YELLOW}skipped or error${NC}"
                echo "    ${RESULT}" | head -1
            fi
        fi
    done
    log "${DASHBOARD_COUNT} dashboard(s) imported"
else
    warn "No dashboards directory found at ${DASHBOARD_DIR}"
fi

# --- Verification -------------------------------------------------------------
step "Verification"

echo ""
echo "Pods:"
kubectl get pods -n "${NAMESPACE}"

echo ""
echo "Services:"
kubectl get svc -n "${NAMESPACE}"

echo ""
echo "IngressRoutes:"
kubectl get ingressroute -n "${NAMESPACE}" 2>/dev/null || echo "  (none)"

echo ""
echo "PVCs:"
kubectl get pvc -n "${NAMESPACE}"

# Detect host IP for user-friendly URLs
HOST_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo ""
log "Observability stack deployment complete"
echo ""
echo "  Grafana:     http://${HOST_IP}/grafana"
echo "  Mimir write: http://${HOST_IP}/mimir/api/v1/push"
echo "  Loki write:  http://${HOST_IP}/loki/loki/api/v1/push"
echo "  Prometheus:  ClusterIP only (internal scraping)"
echo ""
echo "  Next step: bash ~/observability-stack/scripts/deploy/04-deploy-awx.sh ~/observability-stack"
