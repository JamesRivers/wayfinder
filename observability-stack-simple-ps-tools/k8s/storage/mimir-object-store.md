# Mimir object store wiring

## Goal

Define how Mimir uses Garage S3 for durable metric storage.

## Storage model

- Prometheus writes short-retention scrape data locally for alerting and recording rules.
- Mimir receives remote_write from Prometheus and stores long-lived metrics in Garage S3.
- Mimir should not rely on node-local persistence for the main metric archive.

## Required settings

- S3 endpoint
- bucket name
- access key
- secret key
- region or compatibility fields if needed by the object store client
- any path-style or TLS compatibility toggle required by Garage

## Operational notes

- Keep the Mimir config explicit about which components use object storage.
- Store only the durable metric backend in Garage; do not let Prometheus become the long-term archive.
- Prefer a clear separation between query path and durable storage path.

## Verification

- Mimir can write and read from the configured bucket.
- Remote_write ingestion succeeds from Prometheus.
- Restarting Mimir does not lose the long-lived metric archive.
