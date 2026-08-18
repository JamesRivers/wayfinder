# Tempo deployment

## Goal

Provide trace ingestion, storage, and query for the observability platform.

## Deployment posture

- Run Tempo inside the K3s cluster.
- Keep it internal-only.
- Back durable storage with Garage S3.

## Responsibilities

- Receive traces from Alloy
- Store traces durably
- Serve trace queries to Grafana and approved consumers

## Operational notes

- Keep trace storage separate from local scratch data.
- Use Garage S3 consistently with the object-store settings in the storage docs.
- Keep ingestion and query paths easy to reason about.

## Verification

- Alloy can ship traces into Tempo.
- Grafana can query traces from Tempo.
- Restarting Tempo does not lose the durable trace archive.
