#!/usr/bin/env bash
# Gate 3: inside a checkout of the PR branch, merge origin/<base>, resolve spec conflicts that touch different
# requirements, refuse the rest, then validate the source of truth and the archived changes, and wait for CI.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
pr="${1:-}"; [ -n "$pr" ] || die_usage "check-pr.sh <pr-number>   (OPFX_ROOT = checkout of the PR branch, OPFX_CHANGE = change name; a merge commit is pushed to factory/<change>)"
[ -n "${OPFX_CHANGE:-}" ] || die_usage "check-pr.sh: OPFX_CHANGE must name the change (push target factory/<change>)"
require git jq gh
base=$(cfg '.base_branch' main); wait_ci=$(cfg '.gates.wait_ci' true)
cd "$OPFX_ROOT"
git fetch -q origin "$base"
head0=$(git rev-parse HEAD)
mb=$(git merge-base HEAD "origin/$base")

# blocks <rev> <path> : one sorted line per "### Requirement:" block at <rev>: "<header>\t<body with newlines as \x01, trailing blank lines dropped>"
blocks() {
  git show "$1:$2" 2>/dev/null | awk '
    function emit() { sub(/\001+$/, "", b); print h "\t" b }
    /^### Requirement:/ { if (h != "") emit(); h = $0; sub(/^### Requirement: */, "", h); b = ""; next }
    { if (h != "") b = b $0 "\001" }
    END { if (h != "") emit() }' | sort
}
conflicts='[]'; merged=false
if git merge --no-edit "origin/$base" >/dev/null 2>&1; then merged=true; else
  bad=false; tmp=$(mktemp -d)
  while IFS= read -r p; do [ -n "$p" ] || continue
    case "$p" in
      openspec/specs/*)
        # both sides created the file (no base stage): a union would double the preamble, so refuse
        if ! git rev-parse -q --verify ":1:$p" >/dev/null 2>&1; then bad=true
          conflicts=$(jq -c --arg p "$p" '. + [{path:$p, kind:"both-added", requirements:[]}]' <<<"$conflicts"); continue
        fi
        # comm -3 prefixes lines unique to the second file with a tab: strip it before cutting the header field
        ours=$( { comm -3 <(blocks "$mb" "$p") <(blocks HEAD "$p") || true; } | sed 's/^[[:space:]]*//' | cut -f1 | sort -u | sed '/^$/d')
        theirs=$( { comm -3 <(blocks "$mb" "$p") <(blocks "origin/$base" "$p") || true; } | sed 's/^[[:space:]]*//' | cut -f1 | sort -u | sed '/^$/d')
        both=$( { comm -12 <(printf '%s\n' "$ours") <(printf '%s\n' "$theirs") || true; } | sed '/^$/d')
        if [ -n "$both" ]; then bad=true
          conflicts=$(jq -c --arg p "$p" --argjson r "$(printf '%s\n' "$both" | jq -R . | jq -sc .)" '. + [{path:$p, kind:"same-requirement", requirements:$r}]' <<<"$conflicts")
        else
          git show ":1:$p" > "$tmp/base" 2>/dev/null || : > "$tmp/base"
          git show ":2:$p" > "$tmp/ours"; git show ":3:$p" > "$tmp/theirs"
          git merge-file --union -p "$tmp/ours" "$tmp/base" "$tmp/theirs" > "$p" || true
          git add "$p"
          conflicts=$(jq -c --arg p "$p" '. + [{path:$p, kind:"union-merged", requirements:[]}]' <<<"$conflicts")
        fi ;;
      *) bad=true; conflicts=$(jq -c --arg p "$p" '. + [{path:$p, kind:"non-spec", requirements:[]}]' <<<"$conflicts") ;;
    esac
  done < <(git diff --name-only --diff-filter=U)
  if $bad; then git merge --abort >/dev/null 2>&1 || true
    json_out "$(jq -nc --argjson c "$conflicts" '{ok:false, merged:false, conflicts:$c, specsValid:null, archivedValid:null, ci:"skipped"}')"; exit 1
  fi
  git -c user.name="${GIT_AUTHOR_NAME:-opfx}" -c user.email="${GIT_AUTHOR_EMAIL:-opfx@example.com}" commit -qm "merge origin/$base into $(git rev-parse --abbrev-ref HEAD)" && merged=true
  unioned=true
fi
# a union merge that OpenSpec rejects is rolled back: never leave a bad commit in the checkout
if [ "${unioned:-false}" = true ]; then
  sv0=$( { openspec validate --specs --json --no-interactive 2>/dev/null || true; } | jq -r 'if .summary then (.summary.totals.failed == 0) else false end' 2>/dev/null || echo false)
  if [ "$sv0" != true ]; then
    git reset -q --hard ORIG_HEAD
    conflicts=$(jq -c 'map(if .kind=="union-merged" then .kind="union-invalid" else . end)' <<<"$conflicts")
    json_out "$(jq -nc --argjson c "$conflicts" '{ok:false, merged:false, conflicts:$c, specsValid:false, archivedValid:null, ci:"skipped"}')"; exit 1
  fi
fi
sv=$( { openspec validate --specs --json --no-interactive 2>/dev/null || true; } | jq -r 'if .summary then (.summary.totals.failed == 0) else false end' 2>/dev/null || echo false)
av=$( { openspec validate --archived --json --no-interactive 2>/dev/null || true; } | jq -r 'if .summary then (.summary.totals.failed == 0) else false end' 2>/dev/null || echo false)
# push the merge commit before CI, so the checks run on the head that would be merged; the handler never pushes
pushed=false; pushfail=false
if [ "$(git rev-parse HEAD)" != "$head0" ] && [ "$sv" = true ] && [ "$av" = true ]; then
  if git push -q origin "HEAD:refs/heads/factory/$OPFX_CHANGE" 2>/dev/null; then pushed=true; else pushfail=true; fi
fi
ci=skipped
if [ "$wait_ci" = "true" ] && [ -d .github/workflows ]; then
  # a workflow exists, so checks are expected: "no checks reported" right after a push means they are not scheduled yet
  ci=none; tries="${OPFX_CI_RETRIES:-12}"; iv="${OPFX_CI_INTERVAL:-10}"
  for ((i = 1; i <= tries; i++)); do
    if out=$(gh pr checks "$pr" --watch 2>&1); then ci=pass; break
    elif printf '%s' "$out" | grep -q 'no checks reported'; then sleep "$iv"
    else ci=fail; break; fi
  done
fi
ok=true; [ "$sv" = true ] && [ "$av" = true ] && [ "$ci" != fail ] && [ "$pushfail" = false ] || ok=false
json_out "$(jq -nc --argjson ok "$ok" --argjson m "$merged" --argjson p "$pushed" --argjson c "$conflicts" --argjson s "$sv" --argjson a "$av" --arg ci "$ci" '{ok:$ok, merged:$m, pushed:$p, conflicts:$c, specsValid:$s, archivedValid:$a, ci:$ci}')"
$ok
