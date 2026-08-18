# System topology skills

## Purpose

Give the external AI a compact understanding of the observability platform and its surrounding topology.

## Content to include

- The K3s hub host and its role
- Grafana as the human-facing UI and MCP-backed entry point
- Prometheus as the short-retention scraper and alert engine
- Mimir as the long-term metrics backend
- Loki as the logs backend
- Tempo as the traces backend
- Garage S3 as the object store for durable backends
- AWX as the remote Alloy orchestration plane
- Alloy as the target-side telemetry collector
- The monitored ecosystem: hosts, services, network devices, and any known switch-port mappings

## Notes

- Keep the topology textual and explicit.
- Include service relationships and data flow direction.
- Describe what is inside the cluster and what is outside it.
- Pair this with `skills/ecosystem.md` so physical and logical dependencies do not get conflated.
- Never infer a device-to-port mapping unless the source document or inventory says it.

## Verification

- A newcomer can read this file and understand the platform roles.
- The AI can use the topology to reason about where signals originate and where they land.
- Unknown topology edges remain explicitly unknown.
