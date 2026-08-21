#!/usr/bin/env bash
# ==============================================================================
# 04-deploy-awx.sh — Deploy AWX Operator and AWX instance
#
# Usage: bash 04-deploy-awx.sh [REPO_DIR]
#
# What this does:
#   1. Deploys AWX Operator v2.19.1 via kustomize (operator only)
#   2. Waits for operator CRD to be registered
#   3. Applies the AWX CR to create the instance
#   4. Waits for AWX instance to be ready (up to 10 minutes)
#   5. Retrieves and displays the admin password
#
# Prerequisites: K3s running (01-install-k3s.sh completed)
# Note: AWX pulls ~2GB of images on first deploy. Be patient.
# ==============================================================================
set -euo pipefail

# --- Configuration -----------------------------------------------------------
REPO_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
AWX_DEPLOY="${REPO_DIR}/deploy/k8s/awx"
NAMESPACE="awx"
AWX_INSTANCE="observability-awx"

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

if [[ ! -d "${AWX_DEPLOY}" ]]; then
    err "AWX deploy directory not found: ${AWX_DEPLOY}"
    exit 1
fi

log "Cluster reachable, deploy directory found"

# --- Create namespace ---------------------------------------------------------
step "Creating namespace '${NAMESPACE}'"

kubectl apply -f "${AWX_DEPLOY}/namespace.yaml"
log "Namespace created"

# --- Deploy AWX Operator only -------------------------------------------------
step "Deploying AWX Operator v2.19.1"
echo "  Pulling operator from GitHub and container images..."

# Apply the operator from the upstream kustomize ref
kubectl apply -k "https://github.com/ansible/awx-operator/config/default?ref=2.19.1" 2>&1 | while read -r line; do
    echo "  ${line}"
done

log "AWX Operator manifests applied"

# --- Wait for operator to be ready -------------------------------------------
step "Waiting for AWX Operator to be ready (up to 180s)"

for i in $(seq 1 36); do
    if kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep "awx-operator" | grep -q "Running"; then
        log "AWX Operator pod is running"
        break
    fi
    if [[ $i -eq 36 ]]; then
        err "AWX Operator not running after 180s"
        kubectl get pods -n "${NAMESPACE}" 2>/dev/null
        exit 1
    fi
    sleep 5
done

# --- Wait for AWX CRD to be registered ---------------------------------------
step "Waiting for AWX CRD to be registered (up to 60s)"

for i in $(seq 1 12); do
    if kubectl get crd awxs.awx.ansible.com &>/dev/null; then
        log "AWX CRD registered"
        break
    fi
    if [[ $i -eq 12 ]]; then
        err "AWX CRD not registered after 60s"
        exit 1
    fi
    sleep 5
done

# --- Apply AWX instance and ingress ------------------------------------------
step "Deploying AWX instance '${AWX_INSTANCE}'"
echo "  This creates postgres, runs migrations, and starts web + task pods."
echo "  First deploy takes 5-10 minutes for image pulls."

kubectl apply -f "${AWX_DEPLOY}/awx.yaml"
kubectl apply -f "${AWX_DEPLOY}/ingress.yaml"

log "AWX instance CR applied"

# --- Wait for AWX instance to be ready ---------------------------------------
step "Waiting for AWX instance to be ready (up to 600s)"

for i in $(seq 1 120); do
    WEB_READY=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep "${AWX_INSTANCE}-web" | grep -c "Running" || true)
    TASK_READY=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep "${AWX_INSTANCE}-task" | grep -c "Running" || true)

    if [[ "${WEB_READY}" -ge 1 && "${TASK_READY}" -ge 1 ]]; then
        log "AWX instance is ready (web + task pods running)"
        break
    fi

    if [[ $((i % 12)) -eq 0 ]]; then
        echo "  Still waiting... ($(( i * 5 ))s elapsed)"
        kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -v "Completed" | while read -r line; do
            echo "    ${line}"
        done
    fi

    if [[ $i -eq 120 ]]; then
        err "AWX instance did not become ready within 600s"
        kubectl get pods -n "${NAMESPACE}" 2>/dev/null
        exit 1
    fi
    sleep 5
done

# --- Retrieve admin password --------------------------------------------------
step "Retrieving AWX admin password"

AWX_PASS=$(kubectl get secret -n "${NAMESPACE}" "${AWX_INSTANCE}-admin-password" -o jsonpath='{.data.password}' | base64 -d)

if [[ -n "${AWX_PASS}" ]]; then
    log "Admin password retrieved"
else
    err "Could not retrieve admin password"
    exit 1
fi

# --- Verification -------------------------------------------------------------
step "Verification"

echo ""
echo "Pods:"
kubectl get pods -n "${NAMESPACE}"

echo ""
echo "Services:"
kubectl get svc -n "${NAMESPACE}"

HOST_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo ""
echo "Testing AWX API..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "admin:${AWX_PASS}" "http://localhost:30080/api/v2/ping/" 2>/dev/null || echo "000")
if [[ "${HTTP_CODE}" == "200" ]]; then
    log "AWX API responding (HTTP ${HTTP_CODE})"
else
    warn "AWX API returned HTTP ${HTTP_CODE} — may still be initializing"
fi

echo ""
log "AWX deployment complete"
echo ""
echo "  AWX URL:       http://${HOST_IP}:30080"
echo "  AWX Username:  admin"
echo "  AWX Password:  ${AWX_PASS}"
echo "  Password cmd:  kubectl get secret -n awx ${AWX_INSTANCE}-admin-password -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "  Next step:     run 05-seed-awx.sh"
