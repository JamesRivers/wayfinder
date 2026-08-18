# Observability Stack K3s Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Build the concrete K3s-based observability stack for Grafana, Mimir, Prometheus, Loki, Tempo, AWX, Garage S3, and an external AI integration boundary.

**Architecture:**
Single-node K3s will host the observability platform services. Grafana, Mimir, Prometheus, Loki, Tempo, and AWX will run as in-cluster workloads behind ingress and private ClusterIP services, while Garage S3 provides S3-compatible object storage for the long-lived backends. Alloy remains a remote-agent deployment concern driven by AWX, and the AI system remains outside the cluster, consuming read-only MCP endpoints plus a skills pack that describes topology, safe RCA workflows, and observability query patterns.

**Tech Stack:**
- K3s
- Kubernetes manifests / Helm / Kustomize as appropriate to the repo conventions
- AWX Operator
- Grafana
- Prometheus
- Loki
- Tempo
- Mimir
- Garage S3
- Alloy
- MCP for read-only AI integration

---

## Task 1: Establish the repo layout for the stack

**Objective:** Create a clear file structure for Kubernetes manifests, AWX assets, Garage configuration, and AI integration docs.

**Files:**
- Create: `k8s/README.md`
- Create: `k8s/cluster/README.md`
- Create: `k8s/observability/README.md`
- Create: `k8s/awx/README.md`
- Create: `k8s/storage/README.md`
- Create: `ai/README.md`
- Create: `ai/mcp/README.md`
- Create: `ai/skills/README.md`

**Step 1: Draft the structure**
Document what each directory will contain and how it relates to the K3s stack.

**Step 2: Verify the layout**
Run a directory listing and confirm the paths exist.

**Step 3: Commit**
```bash
git add k8s ai
git commit -m "docs: scaffold observability stack layout"
```

---

## Task 2: Define the K3s cluster bootstrap

**Objective:** Specify how the single-node K3s cluster will be installed and prepared for platform workloads.

**Files:**
- Create: `k8s/cluster/install.md`
- Create: `k8s/cluster/ingress.md`
- Create: `k8s/cluster/storage.md`
- Create: `k8s/cluster/namespaces.md`

**Step 1: Write the bootstrap spec**
Include installation prerequisites, node roles, ingress controller choice, and namespace split.

**Step 2: Define persistence**
Document local-path storage for node-local needs and any required static paths.

**Step 3: Verify the design**
Review the docs for a complete install path with no missing prerequisites.

---

## Task 3: Specify Garage S3 for object storage

**Objective:** Document the local object storage backend used by Mimir and Tempo.

**Files:**
- Create: `k8s/storage/garage.md`
- Create: `k8s/storage/mimir-object-store.md`
- Create: `k8s/storage/tempo-object-store.md`

**Step 1: Define Garage topology**
Specify single-node or small-footprint Garage deployment, ports, and persistence.

**Step 2: Define buckets and credentials**
Document the buckets, access keys, and how Mimir and Tempo will consume them.

**Step 3: Verify consumption paths**
Confirm the object-store settings map cleanly into Mimir and Tempo values.

---

## Task 4: Lay out the observability workloads

**Objective:** Define how Grafana, Prometheus, Mimir, Loki, and Tempo are deployed inside K3s.

**Files:**
- Create: `k8s/observability/grafana.md`
- Create: `k8s/observability/prometheus.md`
- Create: `k8s/observability/mimir.md`
- Create: `k8s/observability/loki.md`
- Create: `k8s/observability/tempo.md`

**Step 1: Write deployment notes for each service**
Capture ingress, service types, persistence, config sources, and dependencies.

**Step 2: Define data flows**
Document scrape, remote_write, log shipping, and trace ingestion paths.

**Step 3: Verify operational boundaries**
Confirm which services are internal-only and which have external entrypoints.

---

## Task 5: Specify AWX deployment and Alloy orchestration

**Objective:** Document AWX inside K3s and how it uses inventories and credentials to push Alloy to remote targets.

**Files:**
- Create: `k8s/awx/awx-operator.md`
- Create: `k8s/awx/awx-instance.md`
- Create: `k8s/awx/alloy-playbooks.md`
- Create: `k8s/awx/inventory-model.md`

**Step 1: Define AWX lifecycle**
Specify operator installation, AWX CRs, and persistent storage.

**Step 2: Define target orchestration**
Document Linux SSH and Windows WinRM credential handling and inventory structure.

**Step 3: Verify the remote-agent flow**
Confirm the end-to-end path from AWX job launch to Alloy installation/config reload.

---

## Task 6: Define the external AI integration boundary

**Objective:** Document the AI platform’s external boundary, MCP interface, and skills pack for RCA.

**Files:**
- Create: `ai/mcp/interface.md`
- Create: `ai/skills/topology.md`
- Create: `ai/skills/rca-playbooks.md`
- Create: `ai/skills/query-patterns.md`
- Create: `ai/skills/system-overview.md`

**Step 1: Define read-only access**
Document what the AI can query from Grafana, metrics, logs, traces, and alerts.

**Step 2: Define the skills pack**
Write the topology and RCA context the AI should load.

**Step 3: Verify safety boundaries**
Confirm the AI has no direct write path into the observability stack.

---

## Task 7: Add validation and deployment checks

**Objective:** Create a repeatable verification path for the stack design artifacts.

**Files:**
- Create: `scripts/validate-plan.sh`
- Create: `scripts/check-links.sh`
- Create: `scripts/lint-manifests.sh`

**Step 1: Define validation commands**
List the checks for docs, YAML, and references.

**Step 2: Add a smoke-test checklist**
Document what must be true before the stack is considered ready for implementation.

**Step 3: Verify coverage**
Confirm every major subsystem has a validation step.

---

## Risks and open questions

- Exact packaging format for the K3s manifests: raw YAML, Helm, or Kustomize.
- Whether Garage runs as a single node or clustered object store for the initial version.
- Whether the AI skills pack should live only in repo docs or also be mirrored into the external AI platform.
- The exact ingress controller and DNS strategy for the cluster.

## Next action

Execute Task 1 first, then proceed sequentially with two-stage review: spec compliance and implementation quality.
