title: Bash script to seed Alloy templates into AWX
label: wayfinder:grilling
status: open
blocked-by:
assignee:

## Question

The current workflow for importing the Alloy bundle (project, inventory, credentials, job templates, host groups) into AWX uses an Ansible bootstrap playbook (`bootstrap-awx-alloy.py` / the mon bootstrap). This works but adds complexity — Ansible calling the AWX API via modules, execution environments, collection dependencies — when the underlying operations are straightforward REST API calls against the AWX API.

Decisions needed:

1. Can the Ansible-based AWX bootstrap be replaced with a standalone bash script that uses curl against the AWX API to create/update the project, inventory, credential, job template, and host/group structure?

2. What AWX objects need to be seeded by the script — is the current set (project, inventory, credential, job template, demo hosts/groups) the complete list, or are there objects the Ansible bootstrap handles that a bash script would miss (e.g. execution environments, schedules, notifications)?

3. Should the script be idempotent (create-or-update) so it can be re-run safely after bundle updates, or is a one-shot seed sufficient with manual AWX management afterward?

## Context

- The Ansible bootstrap was designed in ticket 05 as a repeatable CLI-driven step.
- In practice, the AWX API calls are: create org, create project (pointing at the bare git repo), create inventory, create credential, create job template, add hosts to groups.
- The AWX CLI (`awx`) is not installed on the target host; curl is always available.
- The AWX admin password is retrieved from a K8s secret: `kubectl get secret -n awx observability-awx-admin-password -o jsonpath='{.data.password}' | base64 -d`
- AWX API is at `http://localhost:30080/api/v2/` on the hub host.
- The bare repo is at `git://172.16.47.163:9418/alloy-template-bundle.git`.
