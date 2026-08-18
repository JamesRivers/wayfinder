# Query patterns

## Purpose

Give the AI safe query templates for the observability stack.

## Pattern categories

- Metric health checks
- Log stream narrowing
- Trace lookup by service or request path
- Alert correlation queries
- Topology-aware drilldowns

## Rules

- Keep queries scoped to the minimum useful time range.
- Prefer labels, service names, and known paths over free-form broad searches.
- Use the right backend for the question instead of querying everything at once.

## Verification

- Queries are narrow enough to be safe.
- Operators can reuse the patterns manually.
- The AI can explain why a query was chosen.
