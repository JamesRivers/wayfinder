title: K3s stack topology and persistence
label: wayfinder:grilling
status: closed
blocked-by:
assignee: Hermes

## Question

Should the hub stack run as a single-node K3s cluster, a multi-node K3s cluster, or another K3s-only arrangement, and what are the container groups, networks, ingress, and persistent volumes?

Choose the runtime shape, define the externally exposed surfaces, and name the storage boundaries the spec should commit to.

## Resolution

Use a single-node K3s cluster on the observability host. Keep Grafana, Mimir, Prometheus, Loki, Tempo, and support components inside the cluster on private ClusterIP services, expose user-facing entrypoints through K3s ingress, and persist state with the local-path storage class or equivalent node-local persistent volumes. Start with a simple single-node layout because the project is explicitly centered on one observability host and the surrounding AWX/Alloy work is target deployment, not hub clustering.
