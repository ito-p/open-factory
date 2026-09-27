#!/usr/bin/env bash
# The only trace: one GitHub comment per event on an Issue or PR. First line: <kind> | <change> | ... | <iso ts>.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
target="${1:-}"; num="${2:-}"; kind="${3:-}"
[ -n "$target" ] && [ -n "$num" ] && [ -n "$kind" ] || die_usage "trace.sh <issue|pr> <number> <phase|gate|review|rubric|answer|usage|summary|agent> [args]"
case "$target" in issue|pr) ;; *) die_usage "target must be issue or pr" ;; esac
shift 3; require gh jq
ts=$(now_iso); change="${OPFX_CHANGE:-?}"
case "$kind" in
  phase)   [ $# -ge 1 ] || die_usage "phase <name>"; body="phase | $change | $1 | $ts" ;;
  gate)    [ $# -ge 2 ] || die_usage "gate <name> <ok|red> [detail]"; body="gate | $change | $1 | $2 | $ts"; [ -n "${3:-}" ] && body="$body"$'\n\n'"$3" ;;
  review|rubric) [ $# -ge 2 ] && [ -f "$2" ] || die_usage "$kind <R1|R2> <file>"; body="$kind | $change | $1 | $ts"$'\n\n'"$(cat "$2")" ;;
  answer)  [ $# -ge 1 ] || die_usage "answer <text>"; body="answer | $change | $ts"$'\n\n'"$1" ;;
  usage)   [ -n "${1:-}" ] || die_usage "usage <line>   (line must not be empty)"; body="usage | $1" ;;
  summary) [ $# -ge 1 ] && [ -f "$1" ] || die_usage "summary <file>"; body="summary | $change | $ts"$'\n\n'"$(cat "$1")" ;;
  agent)   [ $# -ge 2 ] || die_usage "agent <role> <agent id>   (so a later handler can total this agent's usage)"; body="agent | $change | $1 | $2 | $ts" ;;
  *) die_usage "unknown kind $kind" ;;
esac
if ! out=$( cd "$OPFX_ROOT" && gh "$target" comment "$num" --body "$body" 2>&1 ); then
  json_out "$(jq -nc --arg k "$kind" --arg e "$out" '{ok:false, kind:$k, error:("gh failed: " + $e)}')"; exit 1
fi
url=$(printf '%s\n' "$out" | tail -n 1)
json_out "$(jq -nc --arg u "$url" --arg k "$kind" '{ok:true, kind:$k, url:$u}')"
