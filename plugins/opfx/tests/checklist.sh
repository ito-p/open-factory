#!/usr/bin/env bash
# Every scripts/<name>.(sh|mjs) referenced from skills/agents must exist; every `openspec <verb>` must be a known verb.
set -uo pipefail; cd "$(dirname "$0")/.."; rc=0
for r in $(grep -rhoE 'scripts/[a-z-]+\.(sh|mjs)' skills agents 2>/dev/null | sort -u); do
  [ -f "$r" ] && echo "ok   $r" || { echo "MISSING $r"; rc=1; }
done
verbs=" init update list view archive validate show status instructions new schemas templates context doctor "
for v in $(grep -rhoE 'openspec [a-z]+' skills agents 2>/dev/null | awk '{print $2}' | sort -u); do
  case "$verbs" in *" $v "*) echo "ok   openspec $v";; *) echo "UNKNOWN openspec verb $v"; rc=1;; esac
done
# Agent contracts: phrases the handler/worker scripts and tests rely on must stay in the instructions.
while IFS='|' read -r f pat; do
  grep -qE -- "$pat" "$f" && echo "ok   $f: $pat" || { echo "MISSING $f: $pat"; rc=1; }
done <<'EOF'
agents/handler.md|git worktree add --detach
agents/handler.md|check-pr.sh pushes
agents/handler.md|agent worker <
agents/handler.md|agent reviewer <
agents/handler.md|`agent \|` comments
agents/worker.md|design rules
agents/worker.md|design.docs_dir
agents/reviewer.md|design rules
agents/handler.md|design.docs_dir
agents/handler.md|install dependencies
agents/handler.md|reviewer run is one round
agents/worker.md|--draft
agents/worker.md|gh pr ready
agents/handler.md|pr-review.sh
agents/handler.md|push origin --delete
skills/supervisor/SKILL.md|pr-review.sh
skills/supervisor/SKILL.md|## Intake
skills/supervisor/SKILL.md|opfx:intake
agents/handler.md|opfx:incident
templates/rubric.md|\[incident\]
skills/init/SKILL.md|design.docs_dir
templates/rubric.md|design:required
agents/handler.md|human_review[^.]*\bpr\b
agents/handler.md|red gate 3[^.]*rework:
agents/handler.md|union-invalid
agents/handler.md|both-added
agents/handler.md|proposal-stage[^.]*review: fix
agents/worker.md|commit -m "<change>: apply"
agents/worker.md|git add openspec && git commit -m "<change>: archive"
agents/worker.md|git pull --ff-only
agents/worker.md|`## Purpose`
agents/reviewer.md|`## Purpose`
agents/worker.md|policy files
skills/supervisor/SKILL.md|--since
agents/handler.md|newest `answer \|` comment
agents/handler.md|the human's turn
skills/supervisor/SKILL.md|no instructions of your own
agents/worker.md|scripts/openspec.sh
agents/handler.md|scripts/openspec.sh
agents/worker.md|rooted at `/`
agents/handler.md|rooted at `/`
agents/reviewer.md|rooted at `/`
skills/supervisor/SKILL.md|rooted at `/`
skills/init/SKILL.md|rooted at `/`
agents/worker.md|command -v
agents/handler.md|command -v
agents/reviewer.md|command -v
agents/handler.md|relays it to you
agents/handler.md|do not post it again
skills/supervisor/SKILL.md|relay it to the handler
EOF
# The issue form must parse and use only attribute keys GitHub's issue-form schema knows (ruby ships with macOS and the ubuntu runners).
# templates/openspec-config.yaml is a {{template}} and is checked after rendering, in scripts/tests/test_scaffold.sh.
if command -v ruby >/dev/null; then
  ruby -ryaml -e 'y=YAML.load_file(ARGV[0]); ok=%w[label description placeholder value render options multiple default]
    bad=y["body"].flat_map{|b|(b["attributes"]||{}).keys-ok}; abort "unknown attribute keys #{bad}" unless bad.empty?' templates/issue_template.yml \
    && echo "ok   issue form templates/issue_template.yml" || { echo "INVALID issue form templates/issue_template.yml"; rc=1; }
  ruby -ryaml -e 'y=YAML.load_file(ARGV[0]); ok=%w[label description placeholder value render options multiple default]
    bad=y["body"].flat_map{|b|(b["attributes"]||{}).keys-ok}; abort "unknown attribute keys #{bad}" unless bad.empty?
    abort "incident form must carry opfx:intake and opfx:incident" unless (y["labels"] & %w[opfx:intake opfx:incident]).size == 2' templates/incident_template.yml \
    && echo "ok   incident form templates/incident_template.yml" || { echo "INVALID incident form templates/incident_template.yml"; rc=1; }
fi
# The harness names no design tool: tool-specific words belong to the product repo (AGENTS.md, docs/design).
for w in figma Figma use_figma get_metadata screens-layout; do
  if grep -rqi -- "$w" agents skills templates scripts/*.sh scripts/*.mjs 2>/dev/null; then echo "TOOL-SPECIFIC word '$w' in the plugin"; rc=1; else echo "ok   no '$w' in the plugin"; fi
done
exit $rc
