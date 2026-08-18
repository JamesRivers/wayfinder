# RCA playbooks

## Purpose

Provide the AI with a safe, repeatable way to explain what is happening in the observability stack.

## Playbook outline

- Start with the symptom
- Identify the likely signal source
- Check metrics first when the issue is performance or health related
- Check logs when the issue is behavioral or configuration related
- Check traces when the issue spans services or request paths
- Correlate with alerts and recent topology changes

## Guidance

- Prefer evidence over speculation.
- Call out the specific dashboard, query, log stream, or trace view used.
- Distinguish between observation, hypothesis, and recommendation.

## Verification

- The AI can follow the same RCA pattern repeatedly.
- The output is understandable to operators.
- The playbook stays read-only and advisory.
