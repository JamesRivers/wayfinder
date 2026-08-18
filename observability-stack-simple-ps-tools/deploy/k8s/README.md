# Kubernetes deployment assets

This directory will hold the live deployment manifests for the observability stack.

Current rule of thumb:
- Keep the default Traefik ingress that K3s provides.
- Keep the first cluster single-node on 172.16.47.163.
- Put shared primitives in `base/` and component-specific assets in subdirectories.
- Put in-cluster Grafana MCP assets under `deploy/k8s/ai/` so the read-only evidence layer stays part of the stack while the AI runtime remains external.
