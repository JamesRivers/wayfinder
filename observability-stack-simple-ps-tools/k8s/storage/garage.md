# Garage S3 deployment

## Goal

Provide S3-compatible object storage on the observability host for Mimir and Tempo.

## Alignment with the Garage quick start

Follow the single-node quick-start model as the baseline:

- single-node Garage deployment
- `replication_factor = 1`
- explicit `metadata_dir` and `data_dir`
- S3 API on port `3900`
- RPC on port `3901`
- admin API on port `3903`
- optional web/API proxy on `3902`
- default access key and bucket created at startup when supported by the version

## Deployment posture

- Run Garage as an internal storage service for the stack.
- Keep the initial design simple and local to the observability environment.
- Persist Garage metadata and data on durable local storage so the object store survives restarts.
- Treat the quick start as the source of truth for the first working shape.

## Runtime configuration to mirror

- `metadata_dir` on persistent storage
- `data_dir` on persistent storage
- `db_engine = "sqlite"`
- `replication_factor = 1`
- `rpc_bind_addr = "[::]:3901"`
- `rpc_public_addr` points at the in-cluster Service DNS name `garage.storage.svc.cluster.local:3901`
- `s3_api.api_bind_addr = "[::]:3900"`
- `s3_api.s3_region = "garage"`
- `s3_web.bind_addr = "[::]:3902"`
- `admin.api_bind_addr = "[::]:3903"`

## Credentials and bucket bootstrap

When using a Garage release that supports it, bootstrap with:

- `GARAGE_DEFAULT_ACCESS_KEY`
- `GARAGE_DEFAULT_SECRET_KEY`
- `GARAGE_DEFAULT_BUCKET`
- `--single-node`
- `--default-bucket`

That keeps the first bucket and key creation simple and matches the quick-start flow.

## Responsibilities

- Serve S3-compatible buckets for Mimir and Tempo.
- Keep bucket access credentials separate from K3s service credentials.
- Expose only the endpoints required by the in-cluster consumers and any admin path that is intentionally provisioned.

## Operational notes

- Start with one Garage deployment bound to the observability stack.
- Treat Garage as a storage backend, not a user-facing app.
- Document bucket naming, credentials, and backup expectations alongside the manifests.
- Prefer the Garage CLI for cluster checks and bucket/key setup.

## Verification

- Garage starts cleanly and persists data across restart.
- S3 credentials can authenticate against the API.
- Mimir and Tempo can reach their assigned buckets.
- `garage status` reports a healthy single-node cluster.
- A default bucket exists when bootstrap flags are enabled.
