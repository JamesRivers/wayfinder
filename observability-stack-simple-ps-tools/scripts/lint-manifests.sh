#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"

printf 'Linting markdown manifests in %s\n' "$root_dir"

# Placeholder lint pass for now: ensure markdown files are non-empty.
# This keeps the repo ready for a later YAML/Helm/Kustomize phase.
while IFS= read -r -d '' file; do
  if [[ ! -s "$file" ]]; then
    printf 'Empty file found: %s\n' "$file" >&2
    exit 1
  fi
done < <(find "$root_dir" -name '*.md' -print0)

printf 'Markdown manifest lint pass completed.\n'