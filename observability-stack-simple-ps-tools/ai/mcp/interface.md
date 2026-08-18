# Grafana MCP interface

## Goal

Use Grafana MCP as the canonical read-only interface for deterministic checks, low-token tooling, and any external AI that consumes the same evidence layer.

## Access model

- Read-only by design.
- No direct write path into Grafana, Prometheus, Mimir, Loki, Tempo, or AWX.
- Queries should be bounded, auditable, and safe for operational use.
- Prefer the smallest MCP tool that answers the question.

## Intended capabilities

- Inspect dashboards and panel state in Grafana
- Query metrics through Grafana or approved backend routes
- Query logs and traces for RCA
- Inspect alerts, datasource metadata, and topology context where exposed safely
- Generate deeplinks for human follow-up when needed

## Query modes

- Deterministic/non-AI mode: return structured facts, query results, and links only.
- Low-token local-model mode: use a small local model only to summarize or rank the returned facts.
- Full AI mode: use a larger external or local model for synthesis, but still keep Grafana MCP as the source of evidence.

## Notes on model choice

- TensorFlow is not the preferred integration layer for this problem; it is a training/inference framework, not the agent/orchestration boundary.
- If a local model is wanted, favor a small LLM such as Gemma or similar for summarization and classification only.
- If no model is needed, keep the path fully deterministic and let Grafana MCP plus the skills pack do the work.

## Safety rules

- The AI may explain and recommend, but not apply fixes.
- Any action that changes cluster state stays outside the AI boundary.
- Query templates should favor narrow, explicit lookups over broad unrestricted scans.
- If topology knowledge is missing, say so instead of guessing.

## Verification

- The AI can retrieve observability context.
- The AI cannot mutate the stack.
- Query paths are documented and reproducible.
- The same symptom can be checked in deterministic mode without an LLM if needed.
