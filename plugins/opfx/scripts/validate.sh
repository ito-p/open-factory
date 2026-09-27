#!/usr/bin/env bash
# Gate 1: openspec validate --strict, with INFO "Archive would refuse" treated as red.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
change="${1:-}"; [ -n "$change" ] || die_usage "validate.sh <change>"
require jq
out=$(openspec validate "$change" --strict --json --no-interactive 2>/dev/null || true)
if [ -z "$out" ]; then json_out '{"ok":false,"valid":false,"issues":[],"red":[{"level":"ERROR","message":"openspec validate produced no output"}]}'; exit 1; fi
res=$(jq -c '
  (.items[0] // {valid:false, issues:[{level:"ERROR", message:((.status[0].message // "change not found"))}]}) as $it
  | ($it.issues // []) as $iss
  | ($iss | map(select(.level=="ERROR" or .level=="WARNING" or ((.message // "")|startswith("Archive would refuse"))))) as $red
  | {ok: (($it.valid // false) and ($red|length==0)), valid: ($it.valid // false), issues: $iss, red: $red}' <<<"$out")
json_out "$res"
[ "$(jq -r .ok <<<"$res")" = "true" ]
