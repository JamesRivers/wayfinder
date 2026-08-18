# Garage S3 deployment assets

This folder will hold the Kubernetes manifests for Garage, the S3-compatible backend used by Mimir and Tempo.

Garage quick-start baseline:
- single-node deployment
- `replication_factor = 1`
- persistent `metadata_dir` and `data_dir`
- S3 API on 3900
- RPC on 3901
- admin API on 3903
- optional web/API proxy on 3902
- in-cluster RPC discovery via `garage.storage.svc.cluster.local:3901`

Status:
- host target: 172.16.47.163
- ingress: default Traefik kept in place
- image/version: pending the chosen Garage bundle
- bootstrap mode: follow quick-start single-node defaults

Once the bundle is available, this directory should contain:
- namespace or namespace reference
- deployment/stateful workload definition
- service definition
- persistent volume claim(s)
- config and secrets wiring
- bootstrap env for default access key and default bucket
