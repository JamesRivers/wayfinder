# AWX instance configuration

## Goal

Define the AWX instance resources, storage, and exposure needed to run the control plane.

## Instance posture

- Deploy one AWX instance for the observability stack.
- Use the K3s cluster as the hosting platform.
- Keep the instance in its own namespace with explicit storage and service objects.

## Required components

- AWX custom resource
- backing database
- ingress resource
- persistent volumes / claims
- secret references for admin or bootstrap credentials

## Operational notes

- Keep the instance definition small and readable.
- Prefer stable service names for job execution and user access.
- Document any image or version pinning alongside the instance.

## Verification

- The AWX CR reaches ready state.
- The database and persistent volumes bind.
- The UI loads and accepts logins.
