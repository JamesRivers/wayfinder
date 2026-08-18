title: Observability data planes and retention
label: wayfinder:grilling
status: closed
blocked-by: 01-k3s-stack-topology-and-persistence.md
assignee: Hermes

## Question

How do Prometheus, Mimir, Loki, and Tempo divide responsibilities — what gets scraped, remote_written, stored, or queried where, and what are the retention and backup settings?

Fix the data flow and the durability model so the stack's operational story is unambiguous.

## Resolution

Use Prometheus as the short-retention cluster scraper and alerting engine, with local K3s, node, and service targets scraped directly for operational alerts and recording rules. Remote-write all long-lived metrics to Mimir for durable metric storage and queries, with Prometheus kept on a short local retention window for fast rules and troubleshooting. Send logs to Loki as the central log store and traces to Tempo as the central trace store; both should receive Alloy traffic directly and keep their own indexed/queryable data separate from Prometheus. Prefer Garage S3 as the local S3-compatible object storage backend for Mimir and Tempo, with a local persistent volume for Loki, and set retention by tier: short on Prometheus, medium on Loki, longer on Mimir, and Tempo aligned to the trace-analysis window.
