# External AI integration

This directory holds the documentation and interface definitions for the external AI platform.

Current docs:
- `mcp/interface.md`
- `skills/topology.md`
- `skills/ecosystem.md`
- `skills/rca-playbooks.md`
- `skills/query-patterns.md`

Design boundary:
- Grafana MCP lives inside the K3s observability stack as the read-only front door into Grafana and the surrounding telemetry ecosystem.
- The AI runtime stays external and is not part of this repository's deployment scope.
- The AI consumes a skills pack for topology, ecosystem knowledge, query patterns, and RCA.
- The AI may explain and recommend, but it does not mutate the stack.
- Low-token or non-AI modes are allowed when a deterministic query/response path is sufficient.
