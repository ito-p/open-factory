#!/usr/bin/env bash
source ./assert.sh
R="$(cd .. && pwd)/rubric-parse.sh"; RB="$(cd .. && pwd)/../templates/rubric.md"
f=$(mktemp); cat > "$f" <<'REV'
Some review text.
## rubric-verdict
| id | verdict | evidence |
|---|---|---|
| behavior-change | match | delta has MODIFIED todo-list |
| new-capability-design | no-match | capability exists |
| docs-only | no-match | code touched |
| ui | no-match | no screen changes |
| api | no-match | no routes |
| db | no-match | no schema |
| incident | no-match | not an incident |
REV
assert_exit 0 "parses" -- bash "$R" "$f" --rubric "$RB"
assert_json '.human_review' '["pr"]' "$OUT" "behavior change: human reviews the PR before merge"
assert_json '.mergeable_by' human "$OUT" "default mergeable human"
assert_json '.design_required' false "$OUT" "design not required"
assert_json '.error' null "$OUT" "no error"
g=$(mktemp); cat > "$g" <<'REV'
## rubric-verdict
| id | verdict | evidence |
|---|---|---|
| behavior-change | no-match | skip_specs |
| new-capability-design | no-match | - |
| docs-only | match | only docs/README.md |
| ui | no-match | - |
| api | no-match | - |
| db | no-match | - |
| incident | no-match | - |
REV
assert_exit 0 "handler may merge" -- bash "$R" "$g" --rubric "$RB"
assert_json '.mergeable_by' handler "$OUT" "handler"
assert_json '.human_review' '[]' "$OUT" "no human review"
h=$(mktemp); printf 'no table here\n' > "$h"
assert_exit 0 "test_rubric_malformed_falls_to_human" -- bash "$R" "$h" --rubric "$RB"
assert_json '.mergeable_by' human "$OUT" "malformed → human"
assert_json '.human_review' '["pr"]' "$OUT" "malformed → the rubric's undecidable default (PR review), not a hardcoded plan review"
assert_json '.error != null' true "$OUT" "error set"
u=$(mktemp); cat > "$u" <<'REV'
## rubric-verdict
| id | verdict | evidence |
|---|---|---|
| behavior-change | undecidable | unclear |
| new-capability-design | no-match | - |
| docs-only | no-match | - |
| ui | no-match | - |
| api | no-match | - |
| db | no-match | - |
| incident | no-match | - |
REV
assert_exit 0 "undecidable" -- bash "$R" "$u" --rubric "$RB"
assert_json '.undecidable' '["behavior-change"]' "$OUT" "undecidable listed"
assert_json '.mergeable_by' human "$OUT" "undecidable → human"
assert_json '.human_review' '["pr"]' "$OUT" "undecidable → the rubric's undecidable default (PR review)"
# a matched rule that does not decide mergeable_by leaves it to the no-match default (the human chose "handler merges" there)
rb2=$(mktemp); cat > "$rb2" <<'RB'
## triage
- CRITICAL: x
## rules
- [ui] any change that alters a screen => design:required
- [risky] touches billing => mergeable_by:human
## defaults
- no-match => mergeable_by:handler
- undecidable => human_review:proposal, mergeable_by:human
RB
m=$(mktemp); cat > "$m" <<'REV'
## rubric-verdict
| id | verdict | evidence |
|---|---|---|
| ui | match | screen T1 added |
| risky | no-match | - |
REV
assert_exit 0 "matched rule without mergeable_by" -- bash "$R" "$m" --rubric "$rb2"
assert_json '.mergeable_by' handler "$OUT" "unset mergeable_by falls to the no-match default, not to human"
assert_json '.design_required' true "$OUT" "design still required"
m2=$(mktemp); cat > "$m2" <<'REV'
## rubric-verdict
| id | verdict | evidence |
|---|---|---|
| ui | match | screen T1 added |
| risky | match | billing touched |
REV
assert_exit 0 "matched rule that says human" -- bash "$R" "$m2" --rubric "$rb2"
assert_json '.mergeable_by' human "$OUT" "an explicit human wins over the default"
# the template's defaults must parse as-is (a stray comment after => would become an unknown requirement)
n=$(mktemp); cat > "$n" <<'REV'
## rubric-verdict
| id | verdict | evidence |
|---|---|---|
| behavior-change | no-match | - |
| new-capability-design | no-match | - |
| docs-only | no-match | - |
| ui | no-match | - |
| api | no-match | - |
| db | no-match | - |
| incident | no-match | - |
REV
assert_exit 0 "template defaults parse" -- bash "$R" "$n" --rubric "$RB"
assert_json '.error' null "$OUT" "no unknown requirement from the template's no-match line"
assert_json '.mergeable_by' human "$OUT" "template default: human merges when nothing matches"
a=$(mktemp); cat > "$a" <<'REV'
## rubric-verdict
| id | verdict | evidence |
|---|---|---|
| behavior-change | no-match | - |
| new-capability-design | no-match | - |
| docs-only | no-match | - |
| ui | no-match | - |
| api | match | adds POST /api/todos |
| db | match | adds table todos |
| incident | no-match | - |
REV
assert_exit 0 "api and db rules" -- bash "$R" "$a" --rubric "$RB"
assert_json '.human_review' '["pr"]' "$OUT" "api/db: PR review, not plan review"; assert_json '.design_required' true "$OUT" "api/db: design.md required"
i=$(mktemp); cat > "$i" <<'REV'
## rubric-verdict
| id | verdict | evidence |
|---|---|---|
| behavior-change | no-match | - |
| new-capability-design | no-match | - |
| docs-only | no-match | - |
| ui | no-match | - |
| api | no-match | - |
| db | no-match | - |
| incident | match | Issue carries opfx:incident |
REV
assert_exit 0 "incident rule" -- bash "$R" "$i" --rubric "$RB"
assert_json '.human_review' '["pr"]' "$OUT" "incident: a human reviews the PR"
finish
