# Observability workloads

This folder holds the platform workloads that run inside K3s.

Current docs:
- `grafana.md`
- `prometheus.md`
- `mimir.md`
- `loki.md`
- `tempo.md`

Planned rule of thumb:
- Grafana is the human UI.
- Prometheus is the short-retention scraper and alert engine.
- Mimir is the durable metric backend.
- Loki is the log backend.
- Tempo is the trace backend.
