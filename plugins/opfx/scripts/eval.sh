#!/usr/bin/env bash
# Gate 2: test command, lint command, then every executable in .factory/evals/ (change name as $1). Stops at the first red.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
change="${1:-}"; [ -n "$change" ] || die_usage "eval.sh <change>"
require jq
steps='[]'; ok=true
run_step() { # <name> <cmd...>
  local name="$1"; shift; local out rc tail
  set +e; out=$( cd "$OPFX_ROOT" && "$@" 2>&1 ); rc=$?; set -e
  tail=$(printf '%s\n' "$out" | tail -n 20 | jq -Rs .)
  steps=$(jq -c --arg n "$name" --argjson rc "$rc" --argjson t "$tail" '. + [{name:$n, exit:$rc, tail:$t}]' <<<"$steps")
  [ "$rc" -eq 0 ]
}
tc=$(cfg '.gates.test_command' ''); lc=$(cfg '.gates.lint_command' '')
if [ -n "$tc" ]; then run_step test bash -c "$tc" || ok=false; fi
if $ok && [ -n "$lc" ]; then run_step lint bash -c "$lc" || ok=false; fi
if $ok && [ -d "$OPFX_ROOT/.factory/evals" ]; then
  for f in "$OPFX_ROOT"/.factory/evals/*; do
    [ -f "$f" ] && [ -x "$f" ] || continue
    run_step "eval:$(basename "$f")" "$f" "$change" || { ok=false; break; }
  done
fi
json_out "$(jq -nc --argjson ok "$ok" --argjson s "$steps" '{ok:$ok, steps:$s}')"
$ok
