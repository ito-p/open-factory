#!/usr/bin/env bash
# scaffold.sh <answers.json> [--force] [--no-labels] — set up a product repo for opfx (idempotent).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"; require jq node git
answers="${1:-}"; [ -n "$answers" ] && [ -f "$answers" ] || die_usage "scaffold.sh <answers.json> [--force] [--no-labels]"
shift; force=false; labels=true
for a in "$@"; do case "$a" in --force) force=true;; --no-labels) labels=false;; esac; done
T="$OPFX_SCRIPTS/../templates"; created='[]'; skipped='[]'
put() { # <relpath> <src-file>
  local rel="$1" src="$2" dst="$OPFX_ROOT/$1"
  if [ -f "$dst" ] && ! $force; then skipped=$(jq -c --arg p "$rel" '. + [$p]' <<<"$skipped"); return; fi
  mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"; created=$(jq -c --arg p "$rel" '. + [$p]' <<<"$created")
}
cd "$OPFX_ROOT"
lang=$(jq -r '.language // "ja"' "$answers"); know=$(jq -r '.knowledge // ""' "$answers")
tmp=$(mktemp -d)
jq -s '.[0] * (.[1] | del(.knowledge))' "$T/config.json" "$answers" > "$tmp/config.json"; put .factory/config.json "$tmp/config.json"
put .factory/rubric.md "$T/rubric.md"
put .factory/evals/README.md "$T/evals/README.md"
put .factory/evals/scenario-tests.sh "$T/evals/scenario-tests.sh"
printf '%s\n' "$know" > "$tmp/know.txt"
node "$OPFX_SCRIPTS/render.mjs" "$T/AGENTS.md" "$tmp/AGENTS.md" "KNOWLEDGE=@$tmp/know.txt"; put AGENTS.md "$tmp/AGENTS.md"
if [ ! -d openspec ]; then
  $OPFX_OPENSPEC init --tools claude --language "$lang" --no-animation . >/dev/null 2>&1
  created=$(jq -c '. + ["openspec/"]' <<<"$created")
fi
sed 's/^/  /' "$tmp/know.txt" > "$tmp/ctx.txt"
node "$OPFX_SCRIPTS/render.mjs" "$T/openspec-config.yaml" "$tmp/oc.yaml" "LANGUAGE=$lang" "CONTEXT=@$tmp/ctx.txt"
mkdir -p openspec && cp "$tmp/oc.yaml" openspec/config.yaml
put .github/ISSUE_TEMPLATE/opfx.yml "$T/issue_template.yml"
put .github/ISSUE_TEMPLATE/incident.yml "$T/incident_template.yml"
put .github/pull_request_template.md "$T/pull_request_template.md"
if $labels; then bash "$OPFX_SCRIPTS/labels.sh" >/dev/null; fi
json_out "$(jq -nc --argjson c "$created" --argjson s "$skipped" '{ok:true, created:$c, skipped:$s}')"
