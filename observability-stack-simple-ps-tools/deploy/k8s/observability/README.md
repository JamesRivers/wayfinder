# Observability deployment assets

This folder holds the live manifests for Grafana, Prometheus, Mimir, Tempo, and Loki.

Current expectation:
- Grafana is exposed through Traefik on the raw node IP `172.16.47.163`.
- Grafana data sources are provisioned for Prometheus, Mimir, Loki, and Tempo.
- Prometheus stays internal (ClusterIP, short-retention scraping).
- Mimir uses Garage S3 (single-node, replication_factor: 1).
- Tempo uses Garage S3.
- Loki keeps local persistence initially.
- Mimir and Loki write endpoints are exposed via Traefik IngressRoutes at `/mimir` and `/loki` so remote Alloy agents can push metrics and logs through port 80.
- Ingress manifest: `ingress-write-endpoints.yaml`.
