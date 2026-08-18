# Grafana MCP deployment

This component deploys Grafana MCP inside the K3s cluster as the read-only evidence layer for observability queries.

Current shape:
- Namespace: `ai`
- Image: `grafana/mcp-grafana:1.1.0`
- Transport: `streamable-http`
- Grafana backend: `http://grafana.observability.svc.cluster.local`
- Auth to Grafana: existing Grafana admin credentials from the live stack
- Caller auth: `grafana-mcp-auth` Secret with a random server token

Notes:
- The AI runtime stays external and is not deployed here.
- This service is intended to be read-only from the perspective of the surrounding observability stack.
- The service is ClusterIP-only for now; external access can be added later if the AI runtime needs it.
