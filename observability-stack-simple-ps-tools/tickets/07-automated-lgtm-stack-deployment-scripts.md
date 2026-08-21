title: Automated LGTM stack deployment for fresh Ubuntu instances
label: wayfinder:task
status: open
blocked-by:
assignee: Hermes

## Question

Create a repeatable, script-driven installation path for the full LGTM observability stack on K3s that can be executed on a fresh Ubuntu instance without AI assistance.

## Approach

All deployment is driven by numbered bash scripts in `scripts/deploy/`. An engineer clones this repo, runs the scripts in order, and gets a working stack. No ad-hoc commands — if it isn't in a script, it doesn't happen.

## Script inventory

| Script | Layer | Purpose | Status |
|--------|-------|---------|--------|
| 00-host-prereqs.sh | Host | Passwordless sudo, TERM fix, base packages (curl, git, jq) | |
| 01-install-k3s.sh | Host | Install K3s single-node, wait for ready | |
| 02-deploy-garage.sh | Storage | Garage StatefulSet, layout, buckets, API keys | |
| 03-deploy-observability.sh | LGTM | Prometheus, Mimir, Loki, Tempo, Grafana, datasources, ingress | |
| 04-deploy-awx.sh | AWX | AWX operator + instance, wait for ready | |
| 05-seed-awx.sh | AWX | Seed project, inventory, credential, job template, groups | |
| 06-setup-alloy-repo.sh | Alloy | Bare git repo + git-daemon for Alloy bundle | |
| 07-deploy-grafana-mcp.sh | AI | Grafana MCP sidecar (optional) | |

## Inputs

The scripts take minimal input:
- `MON_HOST_IP` — the IP address of this host (auto-detected if not set)

## Deployment log

Items discovered during monlog3 deployment:

- **TERM=xterm**: Ghostty terminal breaks nano/visudo on remote hosts. Added `export TERM=xterm` to bashrc via 00-host-prereqs.sh.
- **Passwordless sudo**: Required for all deploy scripts. Configured via `/etc/sudoers.d/<user>` in 00-host-prereqs.sh.
- **Base packages**: curl, git, jq needed before anything else.
- **K3s install script**: `set -euo pipefail` with `grep -v | wc -l` returns exit 1 when grep finds no non-matching lines (all pods ready). Fixed with `|| true`. Pods need ~60s to pull images and start on a fresh host.
- **Garage script**: Clean first-time run, no issues. All buckets created and key granted in one pass.
- **Observability script**: Grafana dashboard import needs Basic auth header (`admin:admin` = `YWRtaW46YWRtaW4=` base64). All 5 pods (Prometheus, Mimir, Loki, Tempo, Grafana) start within 60s. IngressRoutes for write endpoints confirmed working externally.
- **AWX deploy**: Must split into two phases — operator first, wait for CRD registration, then apply the AWX CR. Single `kubectl apply -k` fails because the CRD isn't registered yet when the CR is applied.
- **AWX deploy**: The kustomize re-apply may create a new operator replicaset that fails with `ImagePullBackOff` if upstream image tags shift. The original operator pod keeps running. Can safely delete the stale replicaset.
- **AWX seed script**: `GROUPS` is a reserved bash variable (holds user group IDs). Renamed to `INVENTORY_GROUPS`. Job template also needs `ask_inventory_on_launch`, `ask_credential_on_launch`, and `extra_vars` with `confirm_run: yes` set as defaults.
- **Alloy repo**: Bundle content must be pushed separately — the bare repo starts empty. Used `git bundle` to transfer from monlog01 since the hosts are on different networks.
- **Grafana MCP**: Deployment requires a `grafana-mcp-auth` secret with a `server-token` key. Script now generates and creates it automatically. Also exposes MCP externally via NodePort 30800 and prints the full MCP client config (URL + Bearer token) at the end. The MCP server defaults to `-address localhost:8000` and `-allowed-hosts` loopback only — must set `-address 0.0.0.0:8000 -allowed-hosts "*"` for external access.
- **Full deploy time**: ~31 minutes from bare Ubuntu to all services running (AWX image pulls are the bottleneck).
