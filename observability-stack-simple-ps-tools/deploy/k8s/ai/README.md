# AI integration deployment assets

This folder holds the live deployment assets for Grafana MCP inside the K3s stack.

Current expectation:
- Grafana MCP runs in the `ai` namespace.
- The MCP server is read-only from the observability stack's perspective.
- The AI runtime itself stays external and is not deployed here.
- The service starts in `streamable-http` mode and reads Grafana using the live Grafana admin credentials for now.
- Caller authentication for the MCP server is provided by a cluster Secret.
