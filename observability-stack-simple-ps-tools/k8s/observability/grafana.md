# Grafana deployment

## Goal

Provide the main visualization and operator console for the observability stack.

## Deployment posture

- Run Grafana inside the K3s cluster.
- Expose the UI through ingress.
- Keep the service backend internal to the cluster.
- Persist Grafana state if dashboards, folders, or local config need to survive restarts.

## Live status

- Grafana is deployed in the `observability` namespace.
- Ingress host: `http://172.16.47.163` via Traefik on the raw node IP
- Data sources are provisioned for Prometheus, Mimir, Loki, and Tempo.
- The admin account is the default Grafana admin user for now.

## Responsibilities

- Query Mimir for metrics
- Query Loki for logs
- Query Tempo for traces
- Present dashboards and drilldowns for operators
- Serve as the main browser UI for the observability stack

## Operational notes

- Treat Grafana as the primary human entrypoint.
- Keep data-source credentials scoped to read access where possible.
- Make dashboard provisioning explicit so the platform remains reproducible.

## Verification

- Grafana opens through ingress.
- Data sources resolve correctly.
- Dashboards survive restart if persistence is enabled.
