#!/usr/bin/env bash
# ==============================================================================
# 06-setup-alloy-repo.sh — Set up the Alloy bundle bare git repo + git-daemon
#
# Usage: bash 06-setup-alloy-repo.sh [REPO_DIR]
#
# What this does:
#   1. Creates a bare git repo for the Alloy template bundle
#   2. Clones the bundle source, copies it into the bare repo
#   3. Starts git-daemon to serve the repo over git:// protocol
#   4. Verifies the repo is accessible
#
# Prerequisites: K3s running, git installed
# Note: The Alloy bundle source must be available. This script initialises
#       the bare repo from the bundle included in the deploy kit.
# ==============================================================================
set -euo pipefail

# --- Configuration -----------------------------------------------------------
REPO_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
GIT_REPOS_DIR="/tmp/git-repos"
BARE_REPO="${GIT_REPOS_DIR}/alloy-template-bundle.git"
BUNDLE_SOURCE="${REPO_DIR}/alloy-bundle"

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

if ! command -v git &>/dev/null; then
    err "git is not installed"
    exit 1
fi

log "git available"

# --- Create bare repo ---------------------------------------------------------
step "Setting up bare git repo at ${BARE_REPO}"

mkdir -p "${GIT_REPOS_DIR}"

if [[ -d "${BARE_REPO}" ]]; then
    warn "Bare repo already exists at ${BARE_REPO}"
else
    git init --bare "${BARE_REPO}"
    log "Bare repo initialised"
fi

# --- Populate from bundle source if available ---------------------------------
step "Populating bare repo"

if [[ -d "${BUNDLE_SOURCE}" ]]; then
    WORK_DIR=$(mktemp -d)
    cd "${WORK_DIR}"
    git init
    git config user.email "deploy@imagine.io"
    git config user.name "Deploy Script"
    cp -r "${BUNDLE_SOURCE}"/* . 2>/dev/null || true
    cp -r "${BUNDLE_SOURCE}"/.[!.]* . 2>/dev/null || true
    git add -A
    git commit -m "Initial Alloy bundle import" --allow-empty
    git remote add origin "${BARE_REPO}"
    git push origin main 2>/dev/null || git push origin master 2>/dev/null || true
    cd /
    rm -rf "${WORK_DIR}"
    log "Bundle source pushed to bare repo"
else
    warn "No bundle source found at ${BUNDLE_SOURCE}"
    echo "  The bare repo is empty. Push the Alloy bundle to it manually:"
    echo "    cd <alloy-bundle-source>"
    echo "    git remote add origin ${BARE_REPO}"
    echo "    git push origin main"
fi

# --- Start git-daemon ---------------------------------------------------------
step "Starting git-daemon"

# Check if already running
if pgrep -f "git-daemon.*${GIT_REPOS_DIR}" &>/dev/null; then
    warn "git-daemon already running"
else
    nohup git daemon \
        --reuseaddr \
        --base-path="${GIT_REPOS_DIR}" \
        --export-all \
        --enable=receive-pack \
        --listen=0.0.0.0 \
        --port=9418 \
        "${GIT_REPOS_DIR}" &>/dev/null &

    sleep 2

    if pgrep -f "git-daemon.*${GIT_REPOS_DIR}" &>/dev/null; then
        log "git-daemon started on port 9418"
    else
        err "git-daemon failed to start"
        exit 1
    fi
fi

# --- Verification -------------------------------------------------------------
step "Verification"

HOST_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "Bare repo:    ${BARE_REPO}"
echo "git-daemon:   $(pgrep -fa git-daemon | head -1)"

echo ""
echo "Testing git clone..."
TEST_DIR=$(mktemp -d)
if git clone "git://${HOST_IP}:9418/alloy-template-bundle.git" "${TEST_DIR}/test" &>/dev/null; then
    COMMIT_COUNT=$(cd "${TEST_DIR}/test" && git rev-list --count HEAD 2>/dev/null || echo "0")
    log "Clone successful (${COMMIT_COUNT} commits)"
else
    warn "Clone test failed — git-daemon may need a moment"
fi
rm -rf "${TEST_DIR}"

echo ""
log "Alloy repo setup complete"
echo ""
echo "  Bare repo:   ${BARE_REPO}"
echo "  Git URL:     git://${HOST_IP}:9418/alloy-template-bundle.git"
echo "  Next step:   run 05-seed-awx.sh (if AWX is deployed)"
