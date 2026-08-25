#!/usr/bin/env bash
# ==============================================================================
# 05-seed-awx.sh — Seed AWX with Alloy project, inventory, and job template
#
# Usage: bash 05-seed-awx.sh
#
# What this does:
#   1. Retrieves the AWX admin password from the K8s secret
#   2. Creates or updates the 'observability' organisation
#   3. Creates or updates the 'mon' project (pointing at the Alloy bare repo)
#   4. Syncs the project to pull the latest bundle content
#   5. Creates or updates the 'alloy-inventory' inventory
#   6. Creates or updates the 'alloy-credential' machine credential
#   7. Creates or updates the 'alloy-template' job template
#   8. Creates inventory groups from playbooks/vars/alloy.yml and bundle overlays
#
# Prerequisites: AWX running (04-deploy-awx.sh), Alloy repo (06-setup-alloy-repo.sh)
# ==============================================================================
set -euo pipefail

# --- Configuration -----------------------------------------------------------
AWX_PORT="${AWX_PORT:-30080}"
AWX_URL="${AWX_URL:-http://localhost:${AWX_PORT}/api/v2}"
AWX_INSTANCE="${AWX_INSTANCE:-observability-awx}"
NAMESPACE="${NAMESPACE:-awx}"
HOST_IP="${HOST_IP:-$(hostname -I | awk '{print $1}') }"
HOST_IP="${HOST_IP// /}"
BARE_REPO="${ALLOY_BARE_REPO:-/tmp/git-repos/alloy-template-bundle.git}"
GIT_URL="${ALLOY_GIT_URL:-git://${HOST_IP}:9418/alloy-template-bundle.git}"
PLAYBOOK_OVERRIDE="${AWX_PLAYBOOK:-}"
PROJECT_NAME="${AWX_PROJECT_NAME:-mon}"
INVENTORY_NAME="${AWX_INVENTORY_NAME:-alloy-inventory}"
TEMPLATE_NAME="${AWX_TEMPLATE_NAME:-alloy-template}"
ORG_NAME="${AWX_ORG_NAME:-observability}"
CREDENTIAL_NAME="${AWX_CREDENTIAL_NAME:-alloy-credential}"
TARGET_DEFAULT="${AWX_TEMPLATE_TARGET:-all}"

# --- Colours ----------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step() { echo -e "\n${YELLOW}>>> $*${NC}"; }

# --- Kubernetes wrapper ------------------------------------------------------
kcmd() {
    if kubectl version --client >/dev/null 2>&1 && kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
        kubectl "$@"
        return 0
    fi

    if command -v sudo >/dev/null 2>&1 && sudo k3s kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
        sudo k3s kubectl "$@"
        return 0
    fi

    err "Could not access Kubernetes namespace '${NAMESPACE}' via kubectl or sudo k3s kubectl"
    return 1
}

# --- Playbook resolution -----------------------------------------------------
resolve_playbook() {
    if [[ -n "${PLAYBOOK_OVERRIDE}" ]]; then
        echo "${PLAYBOOK_OVERRIDE}"
        return 0
    fi

    if [[ -d "${BARE_REPO}" ]]; then
        if git --git-dir="${BARE_REPO}" show-ref --verify --quiet refs/heads/main; then
            if git --git-dir="${BARE_REPO}" cat-file -e refs/heads/main:playbooks/alloy-deploy.yml 2>/dev/null; then
                echo "playbooks/alloy-deploy.yml"
                return 0
            fi
            if git --git-dir="${BARE_REPO}" cat-file -e refs/heads/main:playbooks/alloy_ubuntu.yml 2>/dev/null; then
                echo "playbooks/alloy_ubuntu.yml"
                return 0
            fi
            if git --git-dir="${BARE_REPO}" cat-file -e refs/heads/main:playbooks/alloy_windows.yml 2>/dev/null; then
                echo "playbooks/alloy_windows.yml"
                return 0
            fi
            if git --git-dir="${BARE_REPO}" cat-file -e refs/heads/main:playbooks/alloy_docker.yml 2>/dev/null; then
                echo "playbooks/alloy_docker.yml"
                return 0
            fi
        fi
    fi

    err "Could not resolve an AWX playbook from ${BARE_REPO}. Set AWX_PLAYBOOK explicitly."
    return 1
}

PLAYBOOK_PATH="$(resolve_playbook)"

# --- AWX API helpers ---------------------------------------------------------
awx_get() {
    curl -fsS -u "admin:${AWX_PASS}" "${AWX_URL}$1"
}

awx_post() {
    curl -fsS -u "admin:${AWX_PASS}" -H "Content-Type: application/json" -X POST "${AWX_URL}$1" -d "$2"
}

awx_patch() {
    curl -fsS -u "admin:${AWX_PASS}" -H "Content-Type: application/json" -X PATCH "${AWX_URL}$1" -d "$2"
}

awx_find_by_name() {
    local endpoint="$1"
    local name="$2"

    awx_get "${endpoint}?name=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "${name}")" \
        | python3 -c "import sys,json; r=json.load(sys.stdin).get('results',[]); print(r[0]['id'] if r else '')" 2>/dev/null || echo ""
}

awx_find_group() {
    local inventory_id="$1"
    local name="$2"

    awx_get "/groups/?name=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "${name}")&inventory=${inventory_id}" \
        | python3 -c "import sys,json; r=json.load(sys.stdin).get('results',[]); print(r[0]['id'] if r else '')" 2>/dev/null || echo ""
}

awx_create_or_patch() {
    local endpoint="$1"
    local name="$2"
    local payload="$3"

    local existing_id
    existing_id="$(awx_find_by_name "${endpoint}" "${name}")"

    if [[ -n "${existing_id}" ]]; then
        awx_patch "${endpoint}${existing_id}/" "${payload}" > /dev/null
        echo "${existing_id}"
    else
        awx_post "${endpoint}" "${payload}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo ""
    fi
}

decode_b64() {
    python3 -c 'import base64,sys; print(base64.b64decode(sys.argv[1]).decode())' "$1"
}

discover_inventory_groups() {
    if [[ ! -d "${BARE_REPO}" ]]; then
        err "Bare repo not found at ${BARE_REPO}"
        return 1
    fi

    if ! git --git-dir="${BARE_REPO}" show-ref --verify --quiet refs/heads/main; then
        err "Bare repo ${BARE_REPO} has no main branch to inspect"
        return 1
    fi

    python3 - "${BARE_REPO}" <<'PY'
import base64
import collections
import os
import re
import subprocess
import sys

bare_repo = sys.argv[1]
treeish = "refs/heads/main"

def git_show(path: str) -> str:
    return subprocess.check_output(
        ["git", f"--git-dir={bare_repo}", "show", f"{treeish}:{path}"],
        text=True,
    )

def git_ls(prefix: str):
    return subprocess.check_output(
        ["git", f"--git-dir={bare_repo}", "ls-tree", "-r", "--name-only", treeish, prefix],
        text=True,
    ).splitlines()

def parse_top_level_list(lines, key):
    out = []
    in_section = False
    for line in lines:
        if re.match(rf"^{re.escape(key)}:\s*$", line):
            in_section = True
            continue
        if in_section and re.match(r"^[A-Za-z0-9_]+:\s*$", line):
            break
        if in_section:
            m = re.match(r"^\s{2}-\s+(.+?)\s*$", line)
            if m:
                out.append(m.group(1).strip())
    return out

def parse_map_of_lists(lines, key):
    out = collections.OrderedDict()
    in_section = False
    current = None
    for line in lines:
        if re.match(rf"^{re.escape(key)}:\s*$", line):
            in_section = True
            continue
        if in_section and re.match(r"^[A-Za-z0-9_]+:\s*$", line):
            break
        if not in_section:
            continue
        m_key = re.match(r"^\s{2}([A-Za-z0-9_.-]+):\s*$", line)
        if m_key:
            current = m_key.group(1)
            out[current] = []
            continue
        m_item = re.match(r"^\s{4}-\s+(.+?)\s*$", line)
        if m_item and current is not None:
            out[current].append(m_item.group(1).strip())
    return out

def parse_map_of_scalars(lines, key):
    out = collections.OrderedDict()
    in_section = False
    for line in lines:
        if re.match(rf"^{re.escape(key)}:\s*$", line):
            in_section = True
            continue
        if in_section and re.match(r"^[A-Za-z0-9_]+:\s*$", line):
            break
        if not in_section:
            continue
        m = re.match(r"^\s{2}([A-Za-z0-9_.-]+):\s+(.+?)\s*$", line)
        if m:
            out[m.group(1)] = m.group(2)
    return out

def sanitize_group_vars(raw):
    lines = raw.splitlines()
    safe_lines = []
    omitted_dynamic = False
    for line in lines:
        if re.match(r"\s*\{%.*%\}\s*$", line):
            omitted_dynamic = True
            break
        safe_lines.append(line)
    safe_raw = "\n".join(safe_lines).rstrip()
    if omitted_dynamic:
        safe_raw = (safe_raw + "\n# dynamic template content omitted for AWX inventory compatibility").strip()
    return safe_raw

def parse_simple_value(text, key):
    for line in text.splitlines():
        m = re.match(rf"\s*{re.escape(key)}:\s*(.+?)\s*$", line)
        if m:
            return m.group(1).strip().strip('"\'')
    return None

def yaml_list_block(name, values):
    lines = [f"{name}:"]
    if values:
        lines.extend([f"  - {value}" for value in values])
    else:
        lines.append("  []")
    return lines

def unique_keep_order(values):
    seen = set()
    out = []
    for value in values:
        if value not in seen:
            seen.add(value)
            out.append(value)
    return out

alloy_lines = git_show("playbooks/vars/alloy.yml").splitlines()
components_by_product = parse_map_of_lists(alloy_lines, "components_by_product")
compose_by_product = parse_map_of_scalars(alloy_lines, "compose_by_product")
windows_groups = parse_top_level_list(alloy_lines, "windows_groups")
linux_groups = parse_top_level_list(alloy_lines, "linux_groups")

overlays = {}
for path in git_ls("playbooks/templates/alloy/group_vars"):
    base = os.path.basename(path)
    if not base.endswith(".yml.j2") or base.startswith('.'):
        continue
    raw = git_show(path)
    product = parse_simple_value(raw, "product")
    if not product:
        continue
    overlays[product] = {
        "file": base,
        "raw": raw,
        "safe": sanitize_group_vars(raw),
        "extra_key": parse_simple_value(raw, "alloy_component_extras"),
    }

def resolve_group_name(alias):
    base = alias.replace('-', '_')
    if base in overlays:
        return base
    file_alias = alias
    for product, meta in overlays.items():
        if meta["file"] == f"{file_alias}.yml.j2":
            return product
    if alias in components_by_product:
        return alias
    if base in components_by_product:
        return base
    return base

ordered_candidates = []
for alias in windows_groups + linux_groups:
    ordered_candidates.append(resolve_group_name(alias))
for product in compose_by_product.keys():
    ordered_candidates.append(product)
for product in components_by_product.keys():
    if product.endswith("_extra") or product.endswith("_extras"):
        continue
    ordered_candidates.append(product)

group_map = collections.OrderedDict()
for product in ordered_candidates:
    if product in group_map:
        continue
    base_components = components_by_product.get(product, [])
    overlay = overlays.get(product)
    extra_key = overlay.get("extra_key") if overlay else None
    extra_components = components_by_product.get(extra_key, []) if extra_key else []
    resolved = unique_keep_order(base_components + extra_components)
    compose_file = compose_by_product.get(product)

    vars_lines = []
    sources = ["playbooks/vars/alloy.yml"]
    if overlay:
        vars_lines.extend(overlay["safe"].splitlines())
        sources.append(f"playbooks/templates/alloy/group_vars/{overlay['file']}")
    else:
        vars_lines.append(f"product: {product}")

    vars_lines.append("# source: playbooks/vars/alloy.yml")
    vars_lines.extend(yaml_list_block("alloy_components_from_product", base_components))
    if extra_key:
        vars_lines.append(f"alloy_component_extras_resolved_from: {extra_key}")
        vars_lines.extend(yaml_list_block("alloy_components_from_extra_set", extra_components))
    if compose_file:
        vars_lines.append(f"compose_file: {compose_file}")
    vars_lines.extend(yaml_list_block("alloy_components_resolved", resolved))

    group_map[product] = {
        "variables": "\n".join(vars_lines).rstrip() + "\n",
        "sources": ", ".join(sources),
    }

for product, item in group_map.items():
    print("\t".join([
        base64.b64encode(product.encode()).decode(),
        base64.b64encode(item["variables"].encode()).decode(),
        base64.b64encode(item["sources"].encode()).decode(),
    ]))
PY
}

# --- Pre-flight checks -------------------------------------------------------
step "Pre-flight checks"

if ! kcmd get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -F "${AWX_INSTANCE}-web" | grep -q Running; then
    err "AWX web pod is not running. Run 04-deploy-awx.sh first."
    exit 1
fi

AWX_PASS=$(kcmd get secret -n "${NAMESPACE}" "${AWX_INSTANCE}-admin-password" -o jsonpath='{.data.password}' | base64 -d)

if [[ -z "${AWX_PASS}" ]]; then
    err "Could not retrieve AWX admin password"
    exit 1
fi

if ! awx_get "/ping/" | grep -q 'ha'; then
    err "AWX API not responding at ${AWX_URL}"
    exit 1
fi

log "AWX API responding, admin password retrieved"
log "Selected playbook: ${PLAYBOOK_PATH}"
log "Project git URL: ${GIT_URL}"

# --- Organisation -----------------------------------------------------------
step "Creating or updating organisation '${ORG_NAME}'"

ORG_ID=$(awx_create_or_patch "/organizations/" "${ORG_NAME}" "{\"name\":\"${ORG_NAME}\",\"description\":\"Observability Platform\"}")
log "Organisation: ${ORG_NAME} (id: ${ORG_ID})"

# --- Project ----------------------------------------------------------------
step "Creating or updating project '${PROJECT_NAME}'"

PROJECT_ID=$(awx_create_or_patch "/projects/" "${PROJECT_NAME}" "{
    \"name\": \"${PROJECT_NAME}\",
    \"description\": \"Alloy Deployment Toolkit\",
    \"organization\": ${ORG_ID},
    \"scm_type\": \"git\",
    \"scm_url\": \"${GIT_URL}\",
    \"scm_branch\": \"main\",
    \"scm_clean\": true,
    \"scm_delete_on_update\": true,
    \"scm_update_on_launch\": true
}")
log "Project: ${PROJECT_NAME} (id: ${PROJECT_ID})"

# --- Sync project -----------------------------------------------------------
step "Syncing project to pull latest from git"

awx_post "/projects/${PROJECT_ID}/update/" '{}' > /dev/null

for i in $(seq 1 60); do
    STATUS=$(awx_get "/projects/${PROJECT_ID}/" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
    if [[ "${STATUS}" == "successful" ]]; then
        REVISION=$(awx_get "/projects/${PROJECT_ID}/" | python3 -c "import sys,json; print(json.load(sys.stdin).get('scm_revision','')[:12])" 2>/dev/null || echo "")
        log "Project synced (revision: ${REVISION})"
        break
    fi
    if [[ "${STATUS}" == "failed" ]]; then
        err "Project sync failed"
        awx_get "/projects/${PROJECT_ID}/" || true
        exit 1
    fi
    sleep 2
done

# --- Inventory --------------------------------------------------------------
step "Creating or updating inventory '${INVENTORY_NAME}'"

INV_ID=$(awx_create_or_patch "/inventories/" "${INVENTORY_NAME}" "{
    \"name\": \"${INVENTORY_NAME}\",
    \"description\": \"Alloy deployment targets\",
    \"organization\": ${ORG_ID},
    \"variables\": \"mon_hub_address: ${HOST_IP}\\nrepo_endpoint: http://${HOST_IP}\\nprometheus_endpoint: http://${HOST_IP}/mimir\\nloki_endpoint: http://${HOST_IP}/loki\"
}")
log "Inventory: ${INVENTORY_NAME} (id: ${INV_ID})"

# --- Credential -------------------------------------------------------------
step "Creating or updating credential '${CREDENTIAL_NAME}'"

CRED_TYPE_ID=$(awx_get "/credential_types/?name=Machine" | python3 -c "import sys,json; r=json.load(sys.stdin).get('results',[]); print(r[0]['id'] if r else '1')" 2>/dev/null || echo "1")

CRED_ID=$(awx_create_or_patch "/credentials/" "${CREDENTIAL_NAME}" "{
    \"name\": \"${CREDENTIAL_NAME}\",
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
log "Credential: ${CREDENTIAL_NAME} (id: ${CRED_ID})"

# --- Job template -----------------------------------------------------------
step "Creating or updating job template '${TEMPLATE_NAME}'"

JT_ID=$(awx_create_or_patch "/job_templates/" "${TEMPLATE_NAME}" "{
    \"name\": \"${TEMPLATE_NAME}\",
    \"description\": \"Deploy Alloy to targets\",
    \"organization\": ${ORG_ID},
    \"project\": ${PROJECT_ID},
    \"inventory\": ${INV_ID},
    \"playbook\": \"${PLAYBOOK_PATH}\",
    \"ask_limit_on_launch\": true,
    \"ask_variables_on_launch\": true,
    \"ask_inventory_on_launch\": true,
    \"ask_credential_on_launch\": true,
    \"extra_vars\": \"{\\\"confirm_run\\\": \\\"yes\\\", \\\"target\\\": \\\"${TARGET_DEFAULT}\\\"}\",
    \"become_enabled\": true
}")

awx_post "/job_templates/${JT_ID}/credentials/" "{\"id\": ${CRED_ID}}" > /dev/null 2>&1 || true
log "Job template: ${TEMPLATE_NAME} (id: ${JT_ID})"

# --- Inventory groups -------------------------------------------------------
step "Creating inventory groups"

GROUP_DISCOVERY_OUTPUT="$(discover_inventory_groups)"

if [[ -z "${GROUP_DISCOVERY_OUTPUT}" ]]; then
    err "No inventory groups could be discovered from playbooks/vars/alloy.yml in ${BARE_REPO}"
    exit 1
fi

while IFS=$'\t' read -r GROUP_B64 VARS_B64 SOURCES_B64; do
    [[ -z "${GROUP_B64:-}" ]] && continue

    GROUP="$(decode_b64 "${GROUP_B64}")"
    GROUP_VARS="$(decode_b64 "${VARS_B64}")"
    GROUP_SOURCES="$(decode_b64 "${SOURCES_B64}")"
    GROUP_PAYLOAD="$(GROUP_VARS_INPUT="${GROUP_VARS}" python3 - "${GROUP}" "${INV_ID}" <<'PY'
import json
import os
import sys

group, inventory_id = sys.argv[1:3]
variables = os.environ.get("GROUP_VARS_INPUT", "")
print(json.dumps({"name": group, "inventory": int(inventory_id), "variables": variables}))
PY
)"

    EXISTING_ID="$(awx_find_group "${INV_ID}" "${GROUP}")"

    if [[ -n "${EXISTING_ID}" ]]; then
        GRP_ID="${EXISTING_ID}"
        awx_patch "/groups/${GRP_ID}/" "${GROUP_PAYLOAD}" > /dev/null 2>&1
        echo "  ${GROUP} (id: ${GRP_ID}) — updated from ${GROUP_SOURCES}"
    else
        GRP_ID=$(awx_post "/groups/" "${GROUP_PAYLOAD}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
        echo "  ${GROUP} (id: ${GRP_ID}) — created from ${GROUP_SOURCES}"
    fi
done <<< "${GROUP_DISCOVERY_OUTPUT}"

log "Inventory groups created"

# --- Verification -----------------------------------------------------------
step "Verification"

echo ""
echo "AWX Objects:"
echo "  Organisation:  ${ORG_NAME} (${ORG_ID})"
echo "  Project:       ${PROJECT_NAME} (${PROJECT_ID})"
echo "  Inventory:     ${INVENTORY_NAME} (${INV_ID})"
echo "  Credential:    ${CREDENTIAL_NAME} (${CRED_ID})"
echo "  Job Template:  ${TEMPLATE_NAME} (${JT_ID})"
echo "  Playbook:      ${PLAYBOOK_PATH}"

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
echo "  To add a host:  Use AWX UI at http://${HOST_IP}:${AWX_PORT}"
echo "                  or curl against ${AWX_URL}/hosts/"
echo ""
echo "  Next step: launch ${TEMPLATE_NAME} in AWX with a host or group limit; the template defaults target=all for legacy playbooks"
