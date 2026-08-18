# Observability stack — map

## Destination

A locked design for a K3s-based observability stack with Grafana, Mimir, Prometheus, Loki, and Tempo, plus AWX-driven Grafana Alloy deployment to Linux and Windows targets and an AI assistant integration that can explain the system using Grafana, MCP, and topology knowledge.

## Notes

- Domain: observability platform design and deployment.
- Scope: K3s on the hub host; Alloy is deployed to targets through AWX; default endpoint templates are part of the UX.
- Tracker: local-markdown (this repo). This file is the map; tickets live in `tickets/NN-slug.md` as children. Open tickets are claimed by setting `assignee:`. Blocking uses `blocked-by:` lines. A resolution is recorded in `## Resolution`, then the ticket is closed and a one-line gist is appended here.
- Working style: wayfinder grilling, one question at a time; prefer lazy-first defaults when a choice can be deferred safely.

## Decisions so far

- [K3s stack topology and persistence](tickets/01-k3s-stack-topology-and-persistence.md) — Use a single-node K3s cluster on the observability host, expose user-facing entrypoints through ingress, and persist state with node-local volumes.
- [Observability data planes and retention](tickets/02-observability-data-planes-and-retention.md) — Prometheus stays short-retention for scraping and alerting, Garage S3 backs Mimir and Tempo object storage, Loki stays on local persistent storage, and retention is tiered by data type.
- [AWX deployment for remote Alloy targets](tickets/03-awx-alloy-endpoint-template-model.md) — Deploy AWX in K3s as the basic control plane, then separately seed/import the Alloy bundle through a repeatable CLI-driven Ansible bootstrap so inventories, credentials, and job templates stay decoupled from the core install.
- [External AI platform, MCP, and skills pack for RCA](tickets/04-ai-integration-for-grafana-and-topology-awareness.md) — Keep the AI outside the observability stack, give it read-only MCP access into Grafana and telemetry backends, and supply a skills pack with topology and RCA context.
- [AWX template import workflow for Alloy bundle updates](tickets/05-awx-template-import-workflow-for-alloy-bundle-updates.md) — Use a repeatable command-line Ansible bootstrap against the host git mirror so current and future Alloy bundle templates import into AWX consistently after the basic AWX install.

## Not yet specified

## Out of scope

- Docker-only deployment for this effort; the destination has been redrawn around K3s.
- Building and operating the live deployment itself; this map ends at the locked design.
