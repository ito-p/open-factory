#!/usr/bin/env bash
# Blocks when a Scenario title from the change's delta specs does not appear in any source or test file of the repo
# (every directory except node_modules, dist, .git, openspec, .factory and docs — so workspaces such as web/ and server/ count).
# Reads the active change, or its archived copy once archive.sh has run (R2 runs the evals after archive).
# Disabled by default (not executable). Enable with: chmod +x .factory/evals/scenario-tests.sh
set -euo pipefail
change="${1:?change}"; missing=0
dir="openspec/changes/$change/specs"
if [ ! -d "$dir" ]; then dir=$(ls -d openspec/changes/archive/*-"$change"/specs 2>/dev/null | tail -n 1 || true); fi
if [ -z "$dir" ] || [ ! -d "$dir" ]; then
  meta="openspec/changes/$change/.openspec.yaml"
  [ -f "$meta" ] || meta=$(ls openspec/changes/archive/*-"$change"/.openspec.yaml 2>/dev/null | tail -n 1 || true)
  if [ -n "$meta" ] && [ -f "$meta" ] && grep -qE '^skip_specs:[[:space:]]*true[[:space:]]*$' "$meta"; then echo "skip_specs: no delta specs to check" >&2; exit 0; fi
  echo "no delta specs for change $change (active or archived)" >&2; exit 1
fi
while IFS= read -r t; do
  grep -rqF --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.git --exclude-dir=openspec --exclude-dir=.factory --exclude-dir=docs -- "$t" . 2>/dev/null || { echo "no test mentions scenario: $t" >&2; missing=$((missing+1)); }
done < <(grep -rh '^#### Scenario:' "$dir" 2>/dev/null | sed -E 's/^#### Scenario: *//')
[ "$missing" -eq 0 ]
