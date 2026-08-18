#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"

printf 'Checking markdown link targets in %s\n' "$root_dir"

missing=0
while IFS= read -r -d '' file; do
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    if [[ "$target" =~ ^https?:// ]]; then
      continue
    fi
    if [[ ! -e "$root_dir/$target" ]]; then
      printf 'Missing link target in %s: %s\n' "$file" "$target" >&2
      missing=1
    fi
  done < <(python3 - "$file" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()
for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)', text):
    print(target)
PY
)
done < <(find "$root_dir" -name '*.md' -print0)

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

printf 'All markdown link targets exist.\n'