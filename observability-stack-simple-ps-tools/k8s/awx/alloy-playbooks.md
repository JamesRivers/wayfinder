# Alloy playbooks and job flow

## Goal

Define the Ansible content AWX uses to deploy and manage Alloy on remote targets, separate from the basic AWX install.

The bundle bootstrap is a command-line Ansible step used to seed and refresh AWX objects such as inventories, groups, credentials, execution environments, and job templates.

## Job flow

1. AWX selects an inventory group.
2. AWX selects the target credentials.
3. AWX runs the Alloy deployment playbook.
4. The playbook installs or updates Alloy.
5. The playbook renders the target-specific Alloy config.
6. The playbook restarts or reloads Alloy if needed.

## Playbook responsibilities

- Install Alloy on Linux and Windows targets
- Apply the pre-authored endpoint template content
- Push config updates cleanly
- Verify the service comes back healthy

## Operational notes

- Keep the playbook idempotent.
- Separate host-specific variables from shared defaults.
- Model template inputs as data, not as hard-coded logic.

## Verification

- AWX can launch the job successfully.
- A test target receives Alloy.
- A config change results in an updated Alloy service state.
