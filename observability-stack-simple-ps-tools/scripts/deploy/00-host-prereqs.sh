#!/usr/bin/env bash
# ==============================================================================
# 00-host-prereqs.sh — Host prerequisites before deploying the stack
#
# Usage: sudo bash 00-host-prereqs.sh
#
# What this does:
#   1. Configures passwordless sudo for the deploy user
#   2. Sets TERM=xterm in bashrc (Ghostty terminal compatibility)
#   3. Installs base packages (curl, git, jq)
#
# Prerequisites: Fresh Ubuntu 24.04/26.04, run as root or with sudo
# ==============================================================================
set -euo pipefail

# --- Configuration -----------------------------------------------------------
INSTALL_USER="${SUDO_USER:-$(whoami)}"
INSTALL_HOME=$(eval echo "~${INSTALL_USER}")

# --- Colours ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step() { echo -e "\n${YELLOW}>>> $*${NC}"; }

# --- Pre-flight ---------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)"
    exit 1
fi

# --- Passwordless sudo --------------------------------------------------------
step "Configuring passwordless sudo for '${INSTALL_USER}'"

SUDOERS_FILE="/etc/sudoers.d/${INSTALL_USER}"
if [[ -f "${SUDOERS_FILE}" ]]; then
    warn "Sudoers file already exists: ${SUDOERS_FILE}"
else
    echo "${INSTALL_USER} ALL=(ALL) NOPASSWD: ALL" > "${SUDOERS_FILE}"
    chmod 440 "${SUDOERS_FILE}"
    log "Passwordless sudo configured"
fi

# --- TERM compatibility -------------------------------------------------------
step "Setting TERM=xterm for terminal compatibility"

if ! grep -q 'export TERM=xterm' "${INSTALL_HOME}/.bashrc" 2>/dev/null; then
    echo 'export TERM=xterm' >> "${INSTALL_HOME}/.bashrc"
    log "TERM=xterm added to ${INSTALL_HOME}/.bashrc"
else
    log "TERM=xterm already set"
fi

# --- Base packages ------------------------------------------------------------
step "Installing base packages"

apt-get update -qq
apt-get install -y -qq curl git jq > /dev/null

log "curl, git, jq installed"

# --- Verification -------------------------------------------------------------
step "Verification"

echo "  User:    ${INSTALL_USER}"
echo "  Sudo:    $(sudo -n -l -U ${INSTALL_USER} 2>&1 | tail -1)"
echo "  curl:    $(curl --version | head -1)"
echo "  git:     $(git --version)"
echo "  jq:      $(jq --version)"

echo ""
log "Host prerequisites complete"
echo "  Next step: run 01-install-k3s.sh"
