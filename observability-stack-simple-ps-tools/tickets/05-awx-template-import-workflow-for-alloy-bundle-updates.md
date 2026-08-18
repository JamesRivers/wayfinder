title: AWX template import workflow for Alloy bundle updates
label: wayfinder:grilling
status: closed
blocked-by: 03-awx-alloy-endpoint-template-model.md
assignee: Hermes

## Question

How should we make the current Alloy templates from the bundle, and future template updates pushed to this host, importable into AWX in a repeatable way?

Define the source of truth, the import/update mechanism, and the verification step so future bundle changes can be loaded into AWX without manual rebuilds.

## Resolution

Create a repeatable AWX bootstrap flow backed by a git mirror of the Alloy bundle on the host. The bootstrap script `scripts/bootstrap-awx-alloy.py` now creates or updates the `imagine` organization, the `mon` project, the `alloy-inventory` inventory, and the `alloy-template` job template in AWX. The project source is `git://172.16.47.163:9418/alloy-template-bundle.git`, and re-running the bootstrap script is the supported refresh path for future bundle updates. Verification was performed by syncing the project successfully and confirming the SCM revision `c48122714d53b1984612fbcd3aa74bce82e45428`.
