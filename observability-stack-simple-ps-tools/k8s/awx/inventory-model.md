# AWX inventory and credential model

## Goal

Define how AWX should represent Linux and Windows Alloy targets.

## Inventory model

- Create inventories that group remote observability targets by role or environment.
- Use host variables for target-specific Alloy config inputs.
- Keep Linux and Windows targets distinguishable in inventory structure.

## Credential model

- Linux targets use SSH credentials.
- Windows targets use WinRM credentials.
- AWX admin and database credentials are separate from target credentials.

## Operational notes

- Keep endpoint template content as inventory-driven data.
- Use sane default values for new hosts so onboarding stays easy.
- Make it obvious which values are shared and which are per-host.

## Verification

- A new target can be added without changing the playbook.
- AWX can run against both Linux and Windows inventories.
- Credential selection is clear and repeatable.
