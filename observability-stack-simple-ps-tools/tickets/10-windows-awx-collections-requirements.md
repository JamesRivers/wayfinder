title: Add Windows Ansible collection requirements to the published Alloy bundle
label: wayfinder:task
status: open
blocked-by:
assignee:

## Question

The Windows Alloy deployment path depends on modules from the `ansible.windows` and `community.windows` collections, but the published bundle can currently be missing `collections/requirements.yml`. We need this tracked so the source repo owner can add the requirements file properly in the repo, rather than relying on a one-off host-side fix.

## Evidence

On `monlog6` (`192.168.90.83`), AWX job 6 for Windows target `magellan_controller_1` failed with:

```text
ERROR! couldn't resolve module/action 'community.windows.win_unzip'.
The error appears to be in '/runner/project/playbooks/alloy_windows.yml': line 40, column 11.
```

This was caused by the published bundle lacking:

```text
collections/requirements.yml
```

A live host-side workaround on `monlog6` proved the fix: after adding `collections/requirements.yml` with the required collections and re-syncing AWX, the project checkout contained the file and the module-resolution blocker was removed.

## Required repo change

Add this file to the source template repo that feeds the AWX bundle:

```yaml
---
collections:
  - name: ansible.windows
  - name: community.windows
```

## Why this matters

Without the requirements file:
- AWX can sync the git project successfully
- but Windows playbooks can still fail at runtime when they call modules like:
  - `community.windows.win_unzip`
  - `community.windows.win_robocopy`
  - `community.windows.win_scheduled_task`
  - `community.windows.win_firewall_rule`
  - `community.windows.win_xml`

So Linux onboarding can look healthy while Windows onboarding remains broken.

## Acceptance criteria

- The upstream/source template repo includes `collections/requirements.yml`.
- The file declares both `ansible.windows` and `community.windows`.
- After publishing the bundle and re-syncing AWX, the AWX project checkout contains that file.
- A rerun of the Windows Alloy job for a test host no longer fails on `community.windows.win_unzip` module resolution.

## Notes

A guard has already been added to the local `06-seed-awx.sh` flow so future runs warn if a Windows playbook exists in the bundle without `collections/requirements.yml`. That warning helps catch the issue earlier, but the real fix belongs in the source repo itself.
