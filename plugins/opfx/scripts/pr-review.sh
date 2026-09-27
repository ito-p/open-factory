#!/usr/bin/env bash
# Reads the human's review of a PR: the latest review per author decides (CHANGES_REQUESTED > APPROVED > COMMENTED);
# line comments are carried so the handler can hand them to the worker as a fix file.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
pr="${1:-}"; [ -n "$pr" ] || die_usage "pr-review.sh <pr-number>   (OPFX_ROOT = product repo)"
require gh jq
cd "$OPFX_ROOT"
v=$(gh pr view "$pr" --json reviewDecision,reviews)
c=$(gh api "repos/{owner}/{repo}/pulls/$pr/comments" 2>/dev/null || echo '[]')
json_out "$(jq -nc --argjson v "$v" --argjson c "$c" '
  (($v.reviews // []) | map({author: .author.login, state: .state, body: .body, submittedAt: .submittedAt}) | sort_by(.submittedAt)) as $r
  | ($r | group_by(.author) | map(last) | map(.state)) as $latest
  | {ok: true,
     decision: (if ($latest | index("CHANGES_REQUESTED")) != null then "CHANGES_REQUESTED"
                elif ($latest | index("APPROVED")) != null then "APPROVED"
                elif ($r | length) > 0 then "COMMENTED" else "none" end),
     reviews: $r,
     comments: ($c | map({path: .path, line: (.line // .original_line), body: .body, author: .user.login}))}')"
