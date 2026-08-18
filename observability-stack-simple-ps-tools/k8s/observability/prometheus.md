# Prometheus deployment

## Goal

Provide short-retention scraping, recording rules, and alerting for the observability cluster.

## Deployment posture

- Run Prometheus inside the K3s cluster.
- Keep it internal-only; do not expose it as the main user UI.
- Use local persistence for its short-retention data if required.

## Live status

- Prometheus is deployed in the `observability` namespace.
- It currently scrapes itself and the Kubernetes API server.
- Remote_write to Mimir is still a later step.

## Responsibilities

- Scrape the K3s and observability targets
- Evaluate recording rules and alerts
- Remote-write long-lived metrics to Mimir
- Act as the short-lived operational metric source

## Operational notes

- Prometheus is not the durable archive.
- Keep retention intentionally short.
- Make scrape targets explicit and readable.

## Verification

- Scrape targets are up.
- Alerts evaluate.
- Remote_write to Mimir succeeds.
