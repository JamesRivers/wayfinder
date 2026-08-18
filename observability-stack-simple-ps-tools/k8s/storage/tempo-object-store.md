# Tempo object store wiring

## Goal

Define how Tempo uses Garage S3 for durable trace storage.

## Storage model

- Alloy sends traces into Tempo.
- Tempo stores trace data in Garage S3.
- Tempo should keep its durable object storage separate from local node storage.

## Required settings

- S3 endpoint
- bucket name
- access key
- secret key
- region or compatibility fields if needed by the object store client
- any path-style or TLS compatibility toggle required by Garage

## Operational notes

- Keep trace ingestion separate from query and storage concerns.
- Treat Tempo as the trace backend, not as a local scratch disk service.
- Document any retention controls next to the trace backend settings.

## Verification

- Tempo can write and read from the configured bucket.
- Alloy can ship traces into Tempo.
- Restarting Tempo does not lose the durable trace archive.
