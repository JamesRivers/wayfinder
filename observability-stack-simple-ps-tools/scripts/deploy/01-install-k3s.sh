#!/usr/bin/env bash
# ==============================================================================
# 01-install-k3s.sh — Install K3s single-node cluster
#
# Usage: sudo bash 01-install-k3s.sh
#
# What this does:
#   1. Installs K3s with default Traefik ingress controller
#   2. Waits for the node to be Ready
#   3. Configures kubectl access for the current user
#   4. Verifies the cluster is healthy
#
# Prerequisites: Fresh Ubuntu 24.04/26.04, internet access, root/sudo
# ==============================================================================
set -euo pipefail

# --- Configuration -----------------------------------------------------------
K3S_VERSION="v1.36.3+k3s1"
INSTALL_USER="${SUDO_USER:-$(whoami)}"
INSTALL_HOME=$(eval echo "~${INSTALL_USER}")

# --- Colours for output ------------------------------------------------------
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

if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)"
    exit 1
fi

if command -v k3s &>/dev/null; then
    warn "K3s is already installed: $(k3s --version | head -1)"
    echo "  To reinstall, run: /usr/local/bin/k3s-uninstall.sh"
    exit 0
fi

log "Running as root, install user: ${INSTALL_USER}"

# --- Install K3s --------------------------------------------------------------
step "Installing K3s ${K3S_VERSION}"

curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh -

log "K3s installed"

# --- Wait for node to be Ready -----------------------------------------------
step "Waiting for node to be Ready (up to 120s)"

for i in $(seq 1 24); do
    if kubectl get nodes --no-headers 2>/dev/null | grep -q ' Ready'; then
        log "Node is Ready"
        break
    fi
    if [[ $i -eq 24 ]]; then
        err "Node did not become Ready within 120s"
        kubectl get nodes 2>/dev/null || true
        exit 1
    fi
    sleep 5
done

# --- Configure kubectl for the install user -----------------------------------
step "Configuring kubectl for user '${INSTALL_USER}'"

mkdir -p "${INSTALL_HOME}/.kube"
cp /etc/rancher/k3s/k3s.yaml "${INSTALL_HOME}/.kube/config"
chown -R "${INSTALL_USER}:${INSTALL_USER}" "${INSTALL_HOME}/.kube"
chmod 600 "${INSTALL_HOME}/.kube/config"

# Add KUBECONFIG to bashrc if not already there
if ! grep -q 'KUBECONFIG' "${INSTALL_HOME}/.bashrc" 2>/dev/null; then
    echo 'export KUBECONFIG=~/.kube/config' >> "${INSTALL_HOME}/.bashrc"
fi

log "kubectl configured at ${INSTALL_HOME}/.kube/config"

# --- Wait for system pods to be running ---------------------------------------
step "Waiting for system pods (up to 180s)"

for i in $(seq 1 36); do
    TOTAL=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l || true)
    NOT_READY=$(kubectl get pods -A --no-headers 2>/dev/null | grep -v -E 'Running|Completed' | wc -l || true)
    if [[ "${TOTAL}" -gt 0 && "${NOT_READY}" -eq 0 ]]; then
        log "All system pods are running"
        break
    fi
    if [[ $i -eq 36 ]]; then
        warn "Some pods still not ready after 180s — check manually"
        kubectl get pods -A 2>/dev/null
        break
    fi
    sleep 5
done

# --- Wait for Traefik specifically -------------------------------------------
step "Waiting for Traefik to be ready (up to 120s)"

for i in $(seq 1 24); do
    if kubectl get svc -n kube-system traefik &>/dev/null; then
        log "Traefik service is available"
        break
    fi
    if [[ $i -eq 24 ]]; then
        warn "Traefik service not found after 120s — check manually"
        break
    fi
    sleep 5
done

# --- Verification -------------------------------------------------------------
step "Verification"

echo ""
echo "K3s version:"
k3s --version

echo ""
echo "Nodes:"
kubectl get nodes -o wide

echo ""
echo "Pods:"
kubectl get pods -A

echo ""
echo "Traefik service:"
kubectl get svc -n kube-system traefik

echo ""
log "K3s installation complete"
echo "  Next step: bash ~/observability-stack/scripts/deploy/02-deploy-garage.sh ~/observability-stack"
