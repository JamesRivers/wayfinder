title: Automated LGTM stack deployment for fresh Ubuntu instances
label: wayfinder:task
status: open
blocked-by:
assignee:

## Question

Create a repeatable, script-driven installation path for the full LGTM observability stack on K3s that can be executed on a fresh Ubuntu 24.04 instance without AI assistance.

The scripts and instructions should cover:

1. K3s single-node cluster installation with default Traefik ingress
2. Namespace creation (storage, observability, awx, ai)
3. Garage S3 object storage deployment and bucket provisioning
4. Full LGTM stack deployment (Prometheus, Mimir, Loki, Tempo, Grafana)
5. Traefik IngressRoute configuration for write endpoints (Mimir, Loki)
6. Grafana datasource provisioning
7. AWX Operator and instance deployment
8. AWX Alloy bundle bootstrap (organization, project, inventory, job template)
9. Grafana MCP sidecar for AI integration

The output should be a set of shell scripts and/or a single bootstrap script that takes minimal input (node IP, optional passwords) and produces a working stack. Include validation checks at each stage.
