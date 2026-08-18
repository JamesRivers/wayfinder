# Observability deployment assets

This folder holds the live manifests for Grafana, Prometheus, Mimir, Tempo, and Loki.

Current expectation:
- Grafana is exposed through Traefik on the raw node IP `172.16.47.163`.
- Grafana data sources are provisioned for Prometheus, Mimir, Loki, and Tempo.
- Prometheus stays internal.
- Mimir uses Garage S3.
- Tempo uses Garage S3.
- Loki keeps local persistence initially.
