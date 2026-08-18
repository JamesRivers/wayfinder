# Ecosystem knowledge

## Purpose

Provide the external AI with the minimum durable understanding it needs about the monitored environment so Grafana MCP results can be interpreted correctly.

## What this skill should capture

- Sites, clusters, and hosts
- Network devices and their management names
- Switch ports, uplinks, and endpoint mappings
- VLANs, subnets, and routing boundaries
- Kubernetes namespaces, workloads, and storage roles
- Service-to-service dependencies
- What lives inside the observability stack vs outside it
- Owner or team boundaries when known

## Source of truth

Populate this file from authoritative sources only, such as:

- CMDB / inventory exports
- Switch configuration or network diagrams
- AWX inventories and job templates
- Kubernetes manifests and service discovery
- Grafana dashboards, alerts, and datasource metadata
- Platform documentation maintained in this repository

## Rules

- Do not invent physical connections or dependencies.
- If a port-to-device mapping is unknown, mark it unknown.
- Prefer explicit facts over inferred ones.
- Keep the model small and current; remove stale relationships.
- Separate observed telemetry from static topology knowledge.

## Suggested structure

### Environment

- Site:
- Cluster:
- Primary host:
- Observability stack boundary:

### Network inventory

- Device:
- Interface/port:
- Connected endpoint:
- VLAN/subnet:
- Notes:

### Service inventory

- Service:
- Namespace or host:
- Purpose:
- Dependencies:
- Related alerts/dashboards:

## Verification

- A newcomer can answer "what is this device connected to?" using only documented facts.
- The AI can use this file as a grounding layer before querying Grafana MCP.
- Unknowns remain explicitly unknown until verified.
