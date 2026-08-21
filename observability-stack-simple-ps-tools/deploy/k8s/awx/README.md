# AWX deployment assets

This folder now contains the local K3s AWX bootstrap assets.

Current posture:
- AWX runs on the observability host in the `awx` namespace.
- The AWX Operator is installed from the upstream `2.19.1` release.
- The AWX instance is named `observability-awx`.
- The instance uses `ClusterIP` service exposure with a Traefik ingress at `/awx`.
- PostgreSQL uses the cluster `local-path` storage class.
- Admin and secret-key credentials are left for the operator to auto-generate initially.

Use this folder to keep the AWX install reproducible and to later wire in the Alloy bundle as a project source.

Current bootstrap path:
- `scripts/bootstrap-awx-alloy.py` creates or updates the AWX organization, project, inventory, and job template.
- The project source is the git mirror on this host: `git://172.16.47.163:9418/alloy-template-bundle.git`.
- Re-running the bootstrap script is the supported refresh path when updated templates are pushed to the host.
- `scripts/deploy/06-setup-alloy-repo.sh` accepts an optional second argument for the bundle source path.
- If `REPO_DIR/alloy-bundle` is missing, `06-setup-alloy-repo.sh` falls back to `~/product-observavility` (and then `~/product-observability`) before warning.
- When the bundle source is itself a git repo, `06-setup-alloy-repo.sh` pushes its current HEAD into `/tmp/git-repos/alloy-template-bundle.git` as branch `main` and sets the bare repo HEAD to `main`.
- `scripts/deploy/05-seed-awx.sh` now auto-detects the deployment playbook from `/tmp/git-repos/alloy-template-bundle.git` and prefers `playbooks/alloy_ubuntu.yml` when `playbooks/alloy-deploy.yml` is absent.
- `scripts/deploy/05-seed-awx.sh` falls back to `sudo k3s kubectl` when the calling user cannot read the K3s kubeconfig directly.

Recommended script-only import flow when using the git-backed product repo:

```bash
bash ~/observability-stack/scripts/deploy/06-setup-alloy-repo.sh \
  ~/observability-stack \
  /home/imagine/product-observavility

bash ~/observability-stack/scripts/deploy/05-seed-awx.sh
```

AWX items covered today:
- Confirmed the AWX project `adt` syncs from the local git mirror and updated it to revision `2ec6bd2`.
- Patched the Alloy bundle so Linux installs download `alloy-linux-amd64.zip` from the Grafana release archive, extract the binary, and install it to `/usr/local/bin/alloy` instead of consuming the host-local HTML response.
- Re-ran the AWX project sync and relaunched `alloy-template` as job `30`; the launch reached the new revision but the job still needs follow-up debugging.
