title: K3s self-observability for immediate stack health
label: wayfinder:task
status: open
blocked-by:
assignee: Hermes

## Question

Add a default self-observability layer so a freshly deployed stack immediately shows the health of the K3s node, namespaces, and core pods without any Alloy client deployments.

## Outcome wanted

Right after running the platform deploy scripts, an engineer should be able to open Grafana and quickly answer:
- Is the K3s node healthy?
- Are the core pods up, restarting, or crash-looping?
- Are Prometheus, Mimir, Loki, Tempo, Grafana, and AWX themselves healthy?
- Are cluster logs from the local K3s host and platform pods visible yet?

## Scope

The local stack should ship with built-in telemetry for itself:
- metrics from the K3s node and running pods into the local Prometheus/Mimir path
- logs from the K3s host and platform workloads into the local Loki path
- basic dashboards and/or Explore-ready labels so problems are visible immediately after install

## Important clarification

Logs should not go into Prometheus. The intended model is:
- metrics -> Prometheus (and optionally remote-write onward to Mimir if that is the local pattern)
- logs -> Loki
- both visible in Grafana out of the box

## Why this matters

Today the stack can come up successfully, but the first useful health signals often appear only after a separate Alloy rollout to another host. That delays debugging when the stack itself is unhealthy, because the platform has very little first-party telemetry about its own K3s node and its own pods.

## Work to define

1. Decide the minimum telemetry set for day-0 visibility.
   - K3s node health
   - pod readiness / restarts
   - PVC/storage health
   - ingress / write endpoint health
   - AWX health
   - core service logs

2. Decide the collection method.
   - native Prometheus scrape targets only
   - kube-state-metrics and/or node-exporter
   - Alloy or Promtail running locally in-cluster for logs and optional metrics
   - whether a lightweight daemonset/deployment is enough for this first cut

3. Add the deployment assets to the script-driven flow.
   - make the self-observability pieces part of `03-deploy-observability.sh` or a clearly documented adjacent step
   - ensure the result works on a fresh single-node K3s install

4. Add default verification.
   - commands and checks to prove data is flowing
   - Grafana queries/dashboards that confirm the local stack is observable before any remote host onboarding

## Suggested acceptance criteria

- After `03-deploy-observability.sh`, Grafana shows health data for the local K3s node and core observability workloads.
- Prometheus/Mimir contains series that identify the local node and the main stack jobs.
- Loki contains logs from the local platform with useful labels for namespace/pod/container or equivalent host labels.
- A new engineer can tell within 5 minutes whether the platform itself is healthy, degraded, or broken.
- The deployment remains script-driven and reproducible from a fresh Ubuntu host.

## Notes

This is specifically about first-party telemetry for the observability control-plane host itself, not just downstream Alloy-managed targets. The goal is immediate platform health visibility during bootstrap and troubleshooting.
