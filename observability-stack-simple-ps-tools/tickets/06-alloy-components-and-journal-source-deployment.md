title: Alloy components and journal source deployment via AWX
label: wayfinder:grilling
status: open
blocked-by:
assignee:

## Question

The Alloy bundle deploys the write pipeline (loki.write, loki.relabel, prometheus.remote_write, prometheus.exporter.self) but does not deploy log source components such as `loki.source.journal.generic` because `alloy_components` defaults to an empty list. The journal source template exists in the bundle (`templates/alloy/loki.source.journal.generic.alloy.j2`) but is never rendered.

Additionally, the `prometheus.remote_write` template currently hardcodes `http://172.16.47.163:9090/api/v1/write` (Prometheus direct), when the design decision is to push metrics to Mimir via the ingress at `http://172.16.47.163/mimir/api/v1/push`.

Decisions needed:

1. What should the default `alloy_components` list be for a "basic" Linux target so that journal logs and self-monitoring metrics ship out of the box without manual AWX inventory variable setup?

2. Should the `prometheus.remote_write` and `loki.write` templates be updated to use the Mimir and Loki ingress endpoints by default, or should those URLs remain inventory-driven variables?

3. Where should the write endpoint URLs be defined — in the role defaults, in AWX inventory variables, or as job template extra vars?

## Context

- The fleet overview dashboard only showed 1 agent because the first host happened to have metrics working. The second host (`local-linux-test2`) had the same gap.
- Both hosts were manually fixed by editing `/etc/imagine/alloy/prometheus.remote_write.alloy` to point at Mimir.
- Neither host has journal logs flowing to Loki because no `loki.source.journal.generic.alloy` file was deployed.
- The `alloy_version` variable was also missing from defaults and has now been added to the bundle (`defaults/main.yml`) as `1.18.1`.
- The `unzip` package dependency was also missing and a task was added to `tasks/ubuntu.yml` to install it.
