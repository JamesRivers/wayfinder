# Validation and deployment checks

## Goal

Define the lightweight checks that keep the observability stack design honest before implementation starts.

## Validation commands

- `scripts/validate-plan.sh` — checks that the key planning files exist
- `scripts/check-links.sh` — checks markdown references between files
- `scripts/lint-manifests.sh` — verifies the markdown manifest set is non-empty

## Smoke-test checklist

- The map and plan are present
- The cluster docs describe a single-node K3s target host
- The object-store docs tie Mimir and Tempo to Garage S3
- The AWX docs describe Alloy rollout to remote targets
- The AI docs stay read-only and advisory

## Verification

- All checks pass from a clean checkout.
- The docs stay internally consistent as the stack evolves.
