#!/usr/bin/env bash
source ./assert.sh
P="$(cd .. && pwd)/pr-review.sh"; export OPFX_ROOT=$(mktemp -d); export GH_LOG=$(mktemp)
assert_exit 2 "needs a pr number" -- bash "$P"
export GH_STUB_PR_JSON='{"reviewDecision":"","reviews":[]}' GH_STUB_API_JSON='[]'
assert_exit 0 "no reviews" -- bash "$P" 9
assert_json '.decision' none "$OUT" "decision none without reviews"; assert_json '.reviews|length' 0 "$OUT" "no reviews listed"
export GH_STUB_PR_JSON='{"reviewDecision":"","reviews":[{"author":{"login":"ito-p"},"state":"COMMENTED","body":"読んだ","submittedAt":"2026-09-27T01:00:00Z"},{"author":{"login":"ito-p"},"state":"APPROVED","body":"よい","submittedAt":"2026-09-27T01:10:00Z"}]}'
assert_exit 0 "approved" -- bash "$P" 9
assert_json '.decision' APPROVED "$OUT" "latest review per author decides: APPROVED"
export GH_STUB_PR_JSON='{"reviewDecision":"","reviews":[{"author":{"login":"ito-p"},"state":"APPROVED","body":"","submittedAt":"2026-09-27T01:00:00Z"},{"author":{"login":"ito-p"},"state":"CHANGES_REQUESTED","body":"並びは新しい順に","submittedAt":"2026-09-27T01:20:00Z"}]}'
export GH_STUB_API_JSON='[{"path":"openspec/changes/x/design.md","line":12,"body":"ここは 201 でなく 200 に","user":{"login":"ito-p"}}]'
assert_exit 0 "changes requested" -- bash "$P" 9
assert_json '.decision' CHANGES_REQUESTED "$OUT" "a later CHANGES_REQUESTED overrides an earlier approval"
assert_json '.comments[0].path' "openspec/changes/x/design.md" "$OUT" "line comment path"; assert_json '.comments[0].line' 12 "$OUT" "line comment line"
assert_json '.reviews[-1].body' "並びは新しい順に" "$OUT" "review body carried"
export GH_STUB_PR_JSON='{"reviewDecision":"","reviews":[{"author":{"login":"a"},"state":"APPROVED","body":"","submittedAt":"2026-09-27T01:00:00Z"},{"author":{"login":"b"},"state":"CHANGES_REQUESTED","body":"x","submittedAt":"2026-09-27T00:50:00Z"}]}'
assert_exit 0 "two reviewers" -- bash "$P" 9
assert_json '.decision' CHANGES_REQUESTED "$OUT" "any reviewer's latest CHANGES_REQUESTED wins over another's approval"
finish
