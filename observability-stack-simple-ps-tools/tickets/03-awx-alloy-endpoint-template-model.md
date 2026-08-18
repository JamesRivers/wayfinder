title: AWX deployment for remote Alloy targets
label: wayfinder:grilling
status: closed
blocked-by: 01-k3s-stack-topology-and-persistence.md
blocked-by: 02-observability-data-planes-and-retention.md
assignee: Hermes

## Question

How should AWX be deployed inside the K3s observability stack so it can orchestrate Alloy installation and configuration on remote Linux and Windows targets?

Define the AWX service placement, its dependencies, credentials and inventory wiring, and the minimum deployment path for pushing Alloy to remote targets.

## Resolution

Deploy AWX inside the same K3s cluster as a first-class observability platform service, using the AWX Operator so its lifecycle is managed like the rest of the stack. Keep AWX behind cluster-internal services and ingress, with its own persistent PostgreSQL-backed state and persistent volumes for its runtime data. Use AWX inventories to model target groups, credentials for SSH on Linux and WinRM on Windows, and a synced project for the Alloy playbooks and templates. The minimum deployment path is: AWX runs the Alloy playbook against inventory hosts, installs or updates the Alloy agent, renders the target-specific config, and restarts the service as needed. This keeps Alloy deployment centralized in AWX while leaving endpoint templates as existing input, not the decision under discussion.
