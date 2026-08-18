# Mimir deployment

## Goal

Provide long-lived metric storage and query for the observability platform.

## Deployment posture

- Run Mimir inside the K3s cluster.
- Keep it internal-only.
- Back durable storage with Garage S3.

## Live status

- Mimir is planned to use the `mimir` Garage bucket.
- It will reuse the Garage default access key for the first pass.
- The first deployment is single-replica and internal-only.

## Responsibilities

- Receive remote_write from Prometheus
- Store long-lived metrics durably
- Serve metric queries to Grafana and other approved consumers

## Operational notes

- Use Garage S3 as the object store backend.
- Keep the configuration explicit about the bucket and credentials.
- Separate the long-term metric store from the short-retention Prometheus path.

## Verification

- Prometheus can remote_write to Mimir.
- Queries return expected long-term metrics.
- Restarting Mimir does not lose data.
