#!/usr/bin/env bash
# ==============================================================================
# 06-setup-alloy-repo.sh — Set up the Alloy bundle bare git repo + git-daemon
#
# Usage: bash 06-setup-alloy-repo.sh [REPO_DIR] [BUNDLE_SOURCE]
#
# What this does:
#   1. Creates a bare git repo for the Alloy template bundle
#   2. Populates it from an explicit bundle source, REPO_DIR/alloy-bundle,
#      or ~/product-observavility
#   3. Preserves git history when the source is itself a git repo
#   4. Starts git-daemon to serve the repo over git:// protocol
#   5. Verifies the repo is accessible
#
# Prerequisites: K3s running, git installed
# ==============================================================================
set -euo pipefail

# --- Configuration -----------------------------------------------------------
REPO_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
EXPLICIT_BUNDLE_SOURCE="${2:-}"
GIT_REPOS_DIR="/tmp/git-repos"
BARE_REPO="${GIT_REPOS_DIR}/alloy-template-bundle.git"
DEFAULT_BUNDLE_SOURCE="${REPO_DIR}/alloy-bundle"
FALLBACK_BUNDLE_SOURCE_1="${HOME}/product-observavility"
FALLBACK_BUNDLE_SOURCE_2="${HOME}/product-observability"

# --- Colours ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step() { echo -e "\n${YELLOW}>>> $*${NC}"; }

# --- Source selection ---------------------------------------------------------
select_bundle_source() {
    if [[ -n "${EXPLICIT_BUNDLE_SOURCE}" ]]; then
        echo "${EXPLICIT_BUNDLE_SOURCE}"
        return 0
    fi

    if [[ -d "${DEFAULT_BUNDLE_SOURCE}" ]]; then
        echo "${DEFAULT_BUNDLE_SOURCE}"
        return 0
    fi

    if [[ -d "${FALLBACK_BUNDLE_SOURCE_1}" ]]; then
        echo "${FALLBACK_BUNDLE_SOURCE_1}"
        return 0
    fi

    if [[ -d "${FALLBACK_BUNDLE_SOURCE_2}" ]]; then
        echo "${FALLBACK_BUNDLE_SOURCE_2}"
        return 0
    fi

    echo "${DEFAULT_BUNDLE_SOURCE}"
}

BUNDLE_SOURCE="$(select_bundle_source)"

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

echo "  Selected bundle source: ${BUNDLE_SOURCE}"

if [[ -d "${BUNDLE_SOURCE}" ]]; then
    if git -C "${BUNDLE_SOURCE}" rev-parse --is-inside-work-tree &>/dev/null; then
        SRC_HEAD=$(git -C "${BUNDLE_SOURCE}" rev-parse HEAD)
        SRC_BRANCH=$(git -C "${BUNDLE_SOURCE}" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "main")
        echo "  Source is a git repo (branch: ${SRC_BRANCH}, head: ${SRC_HEAD})"

        git -C "${BUNDLE_SOURCE}" push "${BARE_REPO}" "HEAD:refs/heads/main"
        git --git-dir="${BARE_REPO}" symbolic-ref HEAD refs/heads/main

        log "Git source pushed to bare repo as main"
    else
        WORK_DIR=$(mktemp -d)
        cd "${WORK_DIR}"
        git init
        git checkout -b main
        git config user.email "deploy@localhost"
        git config user.name "Deploy Script"
        cp -r "${BUNDLE_SOURCE}"/* . 2>/dev/null || true
        cp -r "${BUNDLE_SOURCE}"/.[!.]* . 2>/dev/null || true
        git add -A
        git commit -m "Initial Alloy bundle import" --allow-empty
        git remote add origin "${BARE_REPO}"
        git push origin main
        git --git-dir="${BARE_REPO}" symbolic-ref HEAD refs/heads/main
        cd /
        rm -rf "${WORK_DIR}"
        log "Non-git bundle source pushed to bare repo"
    fi
else
    warn "No bundle source found at ${BUNDLE_SOURCE}"
    echo "  Supported source locations are:"
    echo "    1. explicit second argument"
    echo "    2. ${REPO_DIR}/alloy-bundle"
    echo "    3. ${HOME}/product-observavility"
    echo "    4. ${HOME}/product-observability"
    echo "  Manual fallback:"
    echo "    cd <bundle-source-repo>"
    echo "    git push ${BARE_REPO} HEAD:refs/heads/main"
    echo "    git --git-dir=${BARE_REPO} symbolic-ref HEAD refs/heads/main"
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
echo "Repo HEAD:    $(git --git-dir="${BARE_REPO}" symbolic-ref HEAD 2>/dev/null || echo 'UNSET')"
echo "Refs:"
git --git-dir="${BARE_REPO}" for-each-ref --format='  %(refname:short) %(objectname)' refs/heads || true

echo ""
echo "Testing git clone..."
TEST_DIR=$(mktemp -d)
if git clone "git://${HOST_IP}:9418/alloy-template-bundle.git" "${TEST_DIR}/test" &>/dev/null; then
    if git -C "${TEST_DIR}/test" rev-parse --verify HEAD &>/dev/null; then
        COMMIT_COUNT=$(git -C "${TEST_DIR}/test" rev-list --count HEAD 2>/dev/null || echo "0")
        CLONE_HEAD=$(git -C "${TEST_DIR}/test" rev-parse HEAD 2>/dev/null || echo "UNKNOWN")
        log "Clone successful (${COMMIT_COUNT} commits, head ${CLONE_HEAD})"
    else
        warn "Clone succeeded but the repo has no commits yet"
    fi
else
    warn "Clone test failed — git-daemon may need a moment"
fi
rm -rf "${TEST_DIR}"

echo ""
log "Alloy repo setup complete"
echo ""
echo "  Bundle source: ${BUNDLE_SOURCE}"
echo "  Bare repo:     ${BARE_REPO}"
echo "  Git URL:       git://${HOST_IP}:9418/alloy-template-bundle.git"
echo "  Next step:     bash ~/observability-stack/scripts/deploy/05-seed-awx.sh"
