# AWX operator deployment

## Goal

Run AWX as a first-class workload inside the K3s observability cluster.

## Deployment posture

- Install AWX through the AWX Operator.
- Keep AWX inside the `awx` namespace.
- Back AWX with persistent storage for its database and runtime state.
- Expose the UI only through ingress.

## Responsibilities

- Host job templates for Alloy deployment
- Manage inventories and credentials for remote targets
- Serve as the central control plane for remote agent rollout

## Operational notes

- Treat AWX as platform infrastructure, not as an application under test.
- Keep its credentials separate from observability data-source credentials.
- Use explicit backups for the AWX database and any persistent volume content.

## Verification

- AWX pods are healthy.
- The UI is reachable through ingress.
- State persists across restart.
