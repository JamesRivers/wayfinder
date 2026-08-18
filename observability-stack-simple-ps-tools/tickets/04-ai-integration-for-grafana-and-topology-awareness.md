title: External AI platform, MCP, and skills pack for RCA
label: wayfinder:research
status: closed
blocked-by: 01-k3s-stack-topology-and-persistence.md
blocked-by: 02-observability-data-planes-and-retention.md
blocked-by: 03-awx-alloy-endpoint-template-model.md
assignee: Hermes

## Question

Where should the AI platform live if it must stay external to the K3s observability stack, and what MCP and skills content does it need to investigate RCA safely and effectively?

Define the hosting boundary, the read-only interfaces into Grafana and the telemetry backends, and the knowledge pack the AI should consume.

## Resolution

Keep the AI runtime outside the observability stack as a separate service or host, not a Kubernetes workload in the K3s cluster. Grafana MCP itself belongs inside the K3s stack as the read-only evidence layer that can query Grafana, alerts, metrics, logs, and traces without granting write access to the observability plane. Grafana MCP is the preferred front door for this layer, because it already exposes dashboard, datasource, query, alerting, and deeplink primitives with a strong bias toward narrow context usage. Package system topology, service relationships, safe query patterns, ecosystem knowledge, and RCA playbooks in a skills document set that the AI platform can load as its operating context. The AI layer should be treated as an external analyst and copilot: it may inspect, correlate, and explain, but remediation remains outside the AI boundary and is executed through human action or AWX where appropriate. Low-token or fully non-AI checkers can use the same Grafana MCP path as a deterministic evidence source, with a small local model used only when summarization or ranking is helpful.
