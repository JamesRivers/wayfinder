# Loki deployment

## Goal

Provide log ingestion, storage, and query for the observability platform.

## Deployment posture

- Run Loki inside the K3s cluster.
- Keep it internal-only.
- Use local persistence for the first version unless a later design requires a different store.

## Responsibilities

- Receive logs from Alloy
- Store and index logs for query
- Serve log queries to Grafana and approved consumers

## Operational notes

- Keep log ingestion separate from metrics and traces.
- Preserve a clear retention policy and storage target.
- Avoid exposing Loki directly unless an operator path is required.

## Verification

- Alloy can ship logs to Loki.
- Grafana can query logs from Loki.
- Restarting Loki preserves the expected retained data.
