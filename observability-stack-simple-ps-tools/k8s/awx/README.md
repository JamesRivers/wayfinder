# AWX deployment and Alloy orchestration

This folder holds the AWX control plane and the Alloy rollout model.

Current docs:
- `awx-operator.md`
- `awx-instance.md`
- `alloy-playbooks.md`
- `inventory-model.md`

Rule of thumb:
- AWX runs inside K3s.
- AWX basic is installed separately from the Alloy bundle bootstrap.
- The Alloy bundle bootstrap is a repeatable command-line Ansible step that seeds inventories, credentials, groups, and job templates.
- AWX then manages Alloy on remote targets.
- Inventories and credentials carry the target-specific details.
