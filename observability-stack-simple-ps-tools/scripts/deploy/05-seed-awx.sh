#!/usr/bin/env bash
# ==============================================================================
# 05-seed-awx.sh — Seed AWX with Alloy project, inventory, and job template
#
# Usage: bash 05-seed-awx.sh
#
# What this does:
#   1. Retrieves the AWX admin password from K8s secret
#   2. Creates/updates the 'observability' organisation
#   3. Creates/updates the 'adt' project (pointing at the Alloy bare repo)
#   4. Creates/updates the 'alloy-inventory' inventory
#   5. Creates/updates the 'alloy-credential' machine credential
#   6. Creates/updates the 'alloy-template' job template
#   7. Creates inventory groups from the bundle's product list
#   8. Syncs the project and verifies
#
# Prerequisites: AWX running (04-deploy-awx.sh), Alloy repo (06-setup-alloy-repo.sh)
# ==============================================================================
set -euo pipefail

# --- Configuration -----------------------------------------------------------
AWX_PORT="${AWX_PORT:-30080}"
AWX_URL="http://localhost:${AWX_PORT}/api/v2"
AWX_INSTANCE="observability-awx"
NAMESPACE="awx"

# Git URL for the Alloy bundle — uses host IP by default
HOST_IP=$(hostname -I | awk '{print $1}')
GIT_URL="${ALLOY_GIT_URL:-git://${HOST_IP}:9418/alloy-template-bundle.git}"

# --- Colours ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step() { echo -e "\n${YELLOW}>>> $*${NC}"; }

# Helper: AWX API call (GET)
awx_get() {
    curl -s -u "admin:${AWX_PASS}" "${AWX_URL}$1"
}

# Helper: AWX API call (POST with JSON)
awx_post() {
    curl -s -u "admin:${AWX_PASS}" -H "Content-Type: application/json" -X POST "${AWX_URL}$1" -d "$2"
}

# Helper: AWX API call (PATCH with JSON)
awx_patch() {
    curl -s -u "admin:${AWX_PASS}" -H "Content-Type: application/json" -X PATCH "${AWX_URL}$1" -d "$2"
}

# Helper: find or create an AWX object, returns its ID
awx_find_or_create() {
    local endpoint="$1"
    local name="$2"
    local payload="$3"

    # Search by name
    local existing_id
    existing_id=$(awx_get "${endpoint}?name=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${name}'))")" | python3 -c "import sys,json; r=json.load(sys.stdin).get('results',[]); print(r[0]['id'] if r else '')" 2>/dev/null || echo "")

    if [[ -n "${existing_id}" ]]; then
        echo "${existing_id}"
        return 0
    fi

    # Create
    local new_id
    new_id=$(awx_post "${endpoint}" "${payload}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
    echo "${new_id}"
}

# --- Pre-flight checks -------------------------------------------------------
step "Pre-flight checks"

if ! kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep "${AWX_INSTANCE}-web" | grep -q Running; then
    err "AWX web pod is not running. Run 04-deploy-awx.sh first."
    exit 1
fi

# Retrieve password
AWX_PASS=$(kubectl get secret -n "${NAMESPACE}" "${AWX_INSTANCE}-admin-password" -o jsonpath='{.data.password}' | base64 -d)

if [[ -z "${AWX_PASS}" ]]; then
    err "Could not retrieve AWX admin password"
    exit 1
fi

# Test API
if ! awx_get "/ping/" | grep -q "ha"; then
    err "AWX API not responding at ${AWX_URL}"
    exit 1
fi

log "AWX API responding, admin password retrieved"

# --- Organisation -------------------------------------------------------------
step "Creating organisation 'observability'"

ORG_ID=$(awx_find_or_create "/organizations/" "observability" '{"name":"observability","description":"Observability Platform"}')
log "Organisation: observability (id: ${ORG_ID})"

# --- Project ------------------------------------------------------------------
step "Creating project 'adt'"

PROJECT_ID=$(awx_find_or_create "/projects/" "adt" "{
    \"name\": \"adt\",
    \"description\": \"Alloy Deployment Toolkit\",
    \"organization\": ${ORG_ID},
    \"scm_type\": \"git\",
    \"scm_url\": \"${GIT_URL}\",
    \"scm_branch\": \"main\",
    \"scm_clean\": true,
    \"scm_delete_on_update\": true,
    \"scm_update_on_launch\": false
}")
log "Project: adt (id: ${PROJECT_ID})"

# --- Sync project -------------------------------------------------------------
step "Syncing project to pull latest from git"

awx_post "/projects/${PROJECT_ID}/update/" '{}' > /dev/null

# Wait for sync
for i in $(seq 1 30); do
    STATUS=$(awx_get "/projects/${PROJECT_ID}/" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
    if [[ "${STATUS}" == "successful" ]]; then
        REVISION=$(awx_get "/projects/${PROJECT_ID}/" | python3 -c "import sys,json; print(json.load(sys.stdin).get('scm_revision','')[:12])" 2>/dev/null || echo "")
        log "Project synced (revision: ${REVISION})"
        break
    fi
    if [[ "${STATUS}" == "failed" ]]; then
        err "Project sync failed"
        break
    fi
    sleep 2
done

# --- Inventory ----------------------------------------------------------------
step "Creating inventory 'alloy-inventory'"

INV_ID=$(awx_find_or_create "/inventories/" "alloy-inventory" "{
    \"name\": \"alloy-inventory\",
    \"description\": \"Alloy deployment targets\",
    \"organization\": ${ORG_ID}
}")
log "Inventory: alloy-inventory (id: ${INV_ID})"

# --- Set inventory variables --------------------------------------------------
step "Setting inventory variables"

awx_patch "/inventories/${INV_ID}/" "{
    \"variables\": \"mon_hub_address: ${HOST_IP}\nrepo_endpoint: http://${HOST_IP}\nprometheus_endpoint: http://${HOST_IP}/mimir\nloki_endpoint: http://${HOST_IP}/loki\"
}" > /dev/null 2>&1

log "Inventory variables set (mon_hub_address, repo_endpoint, prometheus_endpoint, loki_endpoint)"

# --- Credential ---------------------------------------------------------------
step "Creating credential 'alloy-credential'"

# Get the machine credential type ID
CRED_TYPE_ID=$(awx_get "/credential_types/?name=Machine" | python3 -c "import sys,json; r=json.load(sys.stdin).get('results',[]); print(r[0]['id'] if r else '1')" 2>/dev/null || echo "1")

CRED_ID=$(awx_find_or_create "/credentials/" "alloy-credential" "{
    \"name\": \"alloy-credential\",
    \"description\": \"SSH credential for Alloy targets\",
    \"organization\": ${ORG_ID},
    \"credential_type\": ${CRED_TYPE_ID},
    \"inputs\": {
        \"username\": \"imagine\",
        \"password\": \"imagine\",
        \"become_method\": \"sudo\",
        \"become_username\": \"root\"
    }
}")
log "Credential: alloy-credential (id: ${CRED_ID})"

# --- Job template -------------------------------------------------------------
step "Creating job template 'alloy-template'"

JT_ID=$(awx_find_or_create "/job_templates/" "alloy-template" "{
    \"name\": \"alloy-template\",
    \"description\": \"Deploy Alloy to targets\",
    \"organization\": ${ORG_ID},
    \"project\": ${PROJECT_ID},
    \"inventory\": ${INV_ID},
    \"playbook\": \"playbooks/alloy-deploy.yml\",
    \"ask_limit_on_launch\": true,
    \"ask_variables_on_launch\": true,
    \"ask_inventory_on_launch\": true,
    \"ask_credential_on_launch\": true,
    \"extra_vars\": \"{\\\"confirm_run\\\": \\\"yes\\\"}\",
    \"become_enabled\": true
}")

# Associate credential with job template
awx_post "/job_templates/${JT_ID}/credentials/" "{\"id\": ${CRED_ID}}" > /dev/null 2>&1 || true

log "Job template: alloy-template (id: ${JT_ID})"

# --- Inventory groups ---------------------------------------------------------
step "Creating inventory groups"

INVENTORY_GROUPS=("basic" "xvr" "iox" "adt_core" "adt_haproxy" "adt_postgres" "adt_rabbitmq" \
        "win_basic" "adcserver" "adcclient" "adcservices" "versio" "nexio" "motion" \
        "docker_fullstack" "docker_basic")

for GROUP in "${INVENTORY_GROUPS[@]}"; do
    # Search for existing group by name in this inventory
    EXISTING_ID=$(awx_get "/groups/?name=${GROUP}&inventory=${INV_ID}" | python3 -c "import sys,json; r=json.load(sys.stdin).get('results',[]); print(r[0]['id'] if r else '')" 2>/dev/null || echo "")

    if [[ -n "${EXISTING_ID}" ]]; then
        echo "  ${GROUP} (id: ${EXISTING_ID}) — exists"
        GRP_ID="${EXISTING_ID}"
    else
        GRP_ID=$(awx_post "/groups/" "{\"name\": \"${GROUP}\", \"inventory\": ${INV_ID}}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
        echo "  ${GROUP} (id: ${GRP_ID})"
    fi

    # Set product variable on the group (group name = product name)
    if [[ -n "${GRP_ID}" ]]; then
        awx_patch "/groups/${GRP_ID}/" "{\"variables\": \"product: ${GROUP}\"}" > /dev/null 2>&1
    fi
done

log "Inventory groups created"

# --- Verification -------------------------------------------------------------
step "Verification"

echo ""
echo "AWX Objects:"
echo "  Organisation:  observability (${ORG_ID})"
echo "  Project:       adt (${PROJECT_ID})"
echo "  Inventory:     alloy-inventory (${INV_ID})"
echo "  Credential:    alloy-credential (${CRED_ID})"
echo "  Job Template:  alloy-template (${JT_ID})"

echo ""
echo "Groups:"
awx_get "/groups/?inventory=${INV_ID}&page_size=50" | python3 -c "
import sys,json
for g in json.load(sys.stdin).get('results',[]):
    print(f'  {g[\"name\"]} (id: {g[\"id\"]})')
" 2>/dev/null || echo "  (could not list)"

echo ""
log "AWX seeding complete"
echo ""
echo "  To add a host:  Use AWX UI at http://${HOST_IP}:30080"
echo "                  or curl against ${AWX_URL}/hosts/"
echo ""
echo "  Next step:      run 06-setup-alloy-repo.sh (if not done)"
echo "                  then 07-deploy-grafana-mcp.sh (optional)"
