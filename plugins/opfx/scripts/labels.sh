#!/usr/bin/env bash
# Creates (or recolors) the opfx:* labels on the product repo from .factory/config.json.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"; require gh jq
f="$OPFX_ROOT/.factory/config.json"; [ -f "$f" ] || die_usage "labels.sh (needs .factory/config.json)"
desc() { case "$1" in
  queued) echo "written by supervisor, not started";; proposed) echo "worker passed gate 1, waiting for R1";;
  review) echo "reviewer or human reviewing";; approved) echo "worker may apply";; pr) echo "handler running R2 and gate 3";;
  blocked) echo "waiting for a human answer";; done) echo "merged";; follow-up) echo "deferred WARNING from a review";;
  *) echo "opfx";; esac; }
made='[]'
while IFS=$'\t' read -r k c; do
  ( cd "$OPFX_ROOT" && gh label create "opfx:$k" --color "${c#\#}" --description "$(desc "$k")" --force >/dev/null )
  made=$(jq -c --arg k "opfx:$k" '. + [$k]' <<<"$made")
done < <(jq -r '.labels | to_entries[] | "\(.key)\t\(.value)"' "$f")
json_out "$(jq -nc --argjson l "$made" '{ok:true, labels:$l}')"
