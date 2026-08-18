# K3s ingress model

## Goal

Define a simple ingress path for Grafana and any other user-facing services that need browser access.

## Choice

Use the default K3s ingress controller for the initial stack unless a later service requirement proves it inadequate.

## Rules

- Keep internal services as ClusterIP only.
- Expose only the small set of browser-facing services through ingress.
- Do not publish Prometheus, Mimir, Loki, Tempo, or AWX data planes directly unless a specific operator path requires it.
- Use DNS names that clearly separate operator access from service internals.

## Suggested entrypoints

- Grafana UI
- AWX UI
- Any later operator console that truly needs direct browser access

## Verification

- Each public service has an ingress resource.
- Internal services have no NodePort exposure.
- The ingress controller is healthy and routing correctly.
