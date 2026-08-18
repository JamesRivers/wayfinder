# K3s storage model

## Goal

Define persistence for the single-node K3s observability stack.

## Storage approach

- Use the built-in local-path storage class for node-local persistent volumes.
- Keep the first version simple and host-local.
- Use explicit PVCs for stateful services that need durability.

## What should persist

- Grafana state and dashboards if not fully externalized
- AWX state and its backing database
- Loki local index/data if retained on local storage
- Any Kubernetes-native stateful services that do not use Garage S3

## What should not depend on local PVCs

- Mimir long-term object storage
- Tempo long-term object storage

Those backends should point at Garage S3 rather than node-local disk for their durable object store.

## Verification

- PVCs bind successfully.
- Stateful pods restart without losing expected data.
- The storage class is the default or explicitly referenced in manifests.
