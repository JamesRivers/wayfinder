#!/usr/bin/env bash
# ==============================================================================
# 02-deploy-garage.sh — Deploy Garage S3 object storage
#
# Usage: bash 02-deploy-garage.sh [REPO_DIR]
#
# What this does:
#   1. Deploys Garage via kustomize into the storage namespace
#   2. Waits for the garage pod to be ready
#   3. Creates S3 buckets for Mimir and Tempo
#   4. Grants the default API key access to all buckets
#
# Prerequisites: K3s running (01-install-k3s.sh completed)
# ==============================================================================
set -euo pipefail

# --- Configuration -----------------------------------------------------------
REPO_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
GARAGE_DEPLOY="${REPO_DIR}/deploy/k8s/storage/garage"
NAMESPACE="storage"

# --- Colours ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step() { echo -e "\n${YELLOW}>>> $*${NC}"; }

# Helper: run a garage CLI command inside the pod
garage_exec() {
    kubectl exec -n "${NAMESPACE}" garage-0 -- /garage "$@" 2>&1 | grep -v "^20[0-9].*INFO"
}

# --- Pre-flight checks -------------------------------------------------------
step "Pre-flight checks"

if ! kubectl get nodes &>/dev/null; then
    err "kubectl cannot reach the cluster. Is K3s running?"
    exit 1
fi

if [[ ! -d "${GARAGE_DEPLOY}" ]]; then
    err "Garage deploy directory not found: ${GARAGE_DEPLOY}"
    err "Pass the repo root as argument: bash 02-deploy-garage.sh /path/to/repo"
    exit 1
fi

log "Cluster reachable, deploy directory found"

# --- Deploy Garage via kustomize ----------------------------------------------
step "Deploying Garage to namespace '${NAMESPACE}'"

kubectl apply -k "${GARAGE_DEPLOY}"

log "Garage manifests applied"

# --- Wait for Garage pod to be ready -----------------------------------------
step "Waiting for Garage pod to be ready (up to 120s)"

kubectl rollout status statefulset/garage -n "${NAMESPACE}" --timeout=120s

log "Garage pod is ready"

# --- Wait a few seconds for the admin API to be available --------------------
sleep 5

# --- Verify Garage is responding ---------------------------------------------
step "Verifying Garage admin API"

STATUS=$(garage_exec status 2>&1 || true)
if echo "${STATUS}" | grep -q "ID"; then
    log "Garage admin API responding"
    echo "${STATUS}"
else
    err "Garage admin API not responding"
    echo "${STATUS}"
    exit 1
fi

# --- Create buckets ----------------------------------------------------------
step "Creating S3 buckets"

BUCKETS=("mimir" "mimir-blocks" "mimir-ruler" "mimir-alertmanager" "tempo")

# Get existing buckets
EXISTING=$(garage_exec bucket list 2>&1 || true)

for BUCKET in "${BUCKETS[@]}"; do
    if echo "${EXISTING}" | grep -q "${BUCKET}"; then
        log "Bucket '${BUCKET}' already exists"
    else
        garage_exec bucket create "${BUCKET}"
        log "Bucket '${BUCKET}' created"
    fi
done

# --- Grant access to default key ----------------------------------------------
step "Granting default API key access to all buckets"

# Get the default key ID from the bootstrap env
DEFAULT_KEY=$(grep GARAGE_DEFAULT_ACCESS_KEY "${GARAGE_DEPLOY}/bootstrap.env" | cut -d= -f2)

if [[ -z "${DEFAULT_KEY}" ]]; then
    err "Could not find GARAGE_DEFAULT_ACCESS_KEY in bootstrap.env"
    exit 1
fi

for BUCKET in "${BUCKETS[@]}"; do
    garage_exec bucket allow --read --write --owner "${BUCKET}" --key "${DEFAULT_KEY}" || true
    log "Key granted access to '${BUCKET}'"
done

# --- Verification -------------------------------------------------------------
step "Verification"

echo ""
echo "Buckets:"
garage_exec bucket list

echo ""
echo "Keys:"
garage_exec key list

echo ""
echo "Service:"
kubectl get svc -n "${NAMESPACE}"

echo ""
log "Garage deployment complete"
echo "  S3 endpoint: http://garage.storage.svc.cluster.local:3900"
echo "  Admin API:   http://garage.storage.svc.cluster.local:3903"
echo "  Next step:   run 03-deploy-observability.sh"
