#!/usr/bin/env bash
# Archive a change with the CLI, but only when every task is [x] (openspec archive --yes would not check).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
change="${1:-}"; [ -n "$change" ] || die_usage "archive.sh <change>"
require jq
lst=$(openspec list --json 2>/dev/null || true); [ -n "$lst" ] || lst='{}'
row=$(jq -c --arg n "$change" '(.changes // [])[] | select(.name==$n)' <<<"$lst")
if [ -z "$row" ]; then json_out "$(jq -nc --arg c "$change" '{ok:false, code:"change_not_found", message:("\($c) is not an active change")}')"; exit 1; fi
total=$(jq -r '.totalTasks // 0' <<<"$row"); done_=$(jq -r '.completedTasks // 0' <<<"$row")
if [ "$total" -eq 0 ] || [ "$done_" -ne "$total" ]; then
  json_out "$(jq -nc --argjson d "$done_" --argjson t "$total" '{ok:false, code:"tasks_incomplete", message:("\($d)/\($t) tasks complete"), completed:$d, total:$t}')"; exit 1
fi
out=$(openspec archive "$change" --yes --json 2>/dev/null || true); [ -n "$out" ] || out='{}'
if [ "$(jq -r '.archive != null' <<<"$out")" = "true" ]; then
  json_out "$(jq -c '{ok:true, archivedAs:.archive.archivedAs, path:.archive.path, totals:(.archive.totals // {}), warnings:(.archive.warnings // [])}' <<<"$out")"
else
  json_out "$(jq -c '{ok:false, code:(.status[0].code // "archive_error"), message:(.status[0].message // "archive failed")}' <<<"$out")"; exit 1
fi
