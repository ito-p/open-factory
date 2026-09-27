#!/usr/bin/env bash
source ./assert.sh
S="$(cd .. && pwd)/scaffold.sh"
d=$(mktemp -d); ( cd "$d" && git init -q . ); export OPFX_ROOT="$d"; export GH_LOG=$(mktemp)
a=$(mktemp); cat > "$a" <<'EOF'
{"base_branch":"develop","language":"ja","gates":{"test_command":"npm test","wait_ci":false},"knowledge":"stack: TypeScript, vitest. Do not touch infra/."}
EOF
assert_exit 0 "scaffold" -- bash "$S" "$a"
for f in .factory/config.json .factory/rubric.md .factory/evals/README.md .factory/evals/scenario-tests.sh AGENTS.md openspec/config.yaml .github/ISSUE_TEMPLATE/opfx.yml .github/ISSUE_TEMPLATE/incident.yml .github/pull_request_template.md; do [ -f "$d/$f" ] && echo "  ok   $f" || { echo "  FAIL missing $f"; FAILS=$((FAILS+1)); }; done
assert_eq "develop" "$(jq -r .base_branch "$d/.factory/config.json")" "answer overrides default"
assert_eq "2" "$(jq -r .orchestration.workers "$d/.factory/config.json")" "default kept"
assert_eq "3" "$(jq -r .gates.max_retries "$d/.factory/config.json")" "nested default kept when sibling overridden"
grep -q 'stack: TypeScript' "$d/AGENTS.md" && echo "  ok   knowledge in AGENTS.md" || { echo "  FAIL knowledge"; FAILS=$((FAILS+1)); }
grep -q 'Language: ja' "$d/openspec/config.yaml" && echo "  ok   language in openspec config" || { echo "  FAIL language"; FAILS=$((FAILS+1)); }
if command -v ruby >/dev/null; then ruby -ryaml -e 'y=YAML.load_file(ARGV[0]); exit(y["context"].include?("stack: TypeScript") ? 0 : 1)' "$d/openspec/config.yaml" 2>/dev/null && echo "  ok   rendered openspec config parses with knowledge inside context" || { echo "  FAIL rendered openspec config"; FAILS=$((FAILS+1)); }; fi
[ -f "$d/.claude/skills/openspec-propose/SKILL.md" ] && echo "  ok   openspec init ran" || { echo "  FAIL openspec init"; FAILS=$((FAILS+1)); }
assert_eq "10" "$(grep -c '^label create opfx:' "$GH_LOG")" "10 labels created (incl. intake and incident)"
grep -q 'label create opfx:intake' "$GH_LOG" && echo "  ok   intake label" || { echo "  FAIL intake label"; FAILS=$((FAILS+1)); }
export GH_CWD_LOG=$(mktemp); ( cd /tmp && bash "$(cd "$(dirname "$S")" && pwd)/labels.sh" >/dev/null ); assert_eq "$(cd "$d" && pwd -P)" "$(tail -n1 "$GH_CWD_LOG")" "labels.sh runs gh in OPFX_ROOT"
grep -q 'label create opfx:blocked --color F0883E' "$GH_LOG" && echo "  ok   color without #" || { echo "  FAIL color"; FAILS=$((FAILS+1)); }
echo 'keep' > "$d/AGENTS.md"; assert_exit 0 "idempotent" -- bash "$S" "$a" --no-labels
assert_eq "keep" "$(cat "$d/AGENTS.md")" "existing file kept"
assert_json '.skipped | index("AGENTS.md") != null' true "$OUT" "reported skipped"
[ -e "$d/docs/design" ] && { echo "  FAIL scaffold must not seed design docs (the project owns them)"; FAILS=$((FAILS+1)); } || echo "  ok   no design docs seeded"
assert_eq "docs/design" "$(jq -r .design.docs_dir "$d/.factory/config.json")" "design.docs_dir default"
assert_eq "null" "$(jq -r '.design.figma_file' "$d/.factory/config.json")" "no tool-specific key in config"
finish
