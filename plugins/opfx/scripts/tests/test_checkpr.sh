#!/usr/bin/env bash
source ./assert.sh; source ./fixture.sh
C="$(cd .. && pwd)/check-pr.sh"; A="$(cd .. && pwd)/archive.sh"
d=$(make_fixture); bare=$(mktemp -d); git init -q --bare "$bare"
( cd "$d" && git branch -M main && git remote add origin "$bare" && git push -q origin main )
# branch A: adds a new requirement to todo-list (disjoint from what main will change)
( cd "$d" && git checkout -q -b factory/1-a )
add_change "$d" 1-a added-ok
( cd "$d" && OPFX_ROOT="$d" bash "$A" 1-a >/dev/null && git add -A && git commit -qm "archive 1-a" && git push -q origin factory/1-a )
# main moves: a change that MODIFIES 'todo の一覧' is archived on main
( cd "$d" && git checkout -q main )
( cd "$d" && $FIX_OPENSPEC new change 2-b >/dev/null 2>&1; c=openspec/changes/2-b; mkdir -p $c/specs/todo-list
  printf '# Proposal\n\n## Why\n\n並びを変えたい。理由は最近の項目を先に見たいからで、この文は五十字を超える。\n\n## What Changes\n\n- x\n\n## Capabilities\n\n### New Capabilities\n\n### Modified Capabilities\n- `todo-list`: x\n\n## Impact\n\nx\n' > $c/proposal.md
  printf '# Spec Delta\n\n## MODIFIED Requirements\n\n### Requirement: todo の一覧\nThe system SHALL 登録済みの todo を新しい順に返す。\n\n#### Scenario: 空のとき\n- **WHEN** todo が 1 件も無い\n- **THEN** 空の一覧を返す\n\n#### Scenario: 2 件あるとき\n- **WHEN** todo が 2 件ある\n- **THEN** 新しい順に 2 件を返す\n' > $c/specs/todo-list/spec.md
  printf '# Tasks\n\n## 1. a\n\n- [x] 1.1 done\n' > $c/tasks.md
  $FIX_OPENSPEC archive 2-b --yes --json >/dev/null; git add -A; git commit -qm "archive 2-b"; git push -q origin main )
# handler checkout of branch A
wt=$(mktemp -d); rm -rf "$wt"; git clone -q "$bare" "$wt"; ( cd "$wt" && git checkout -q factory/1-a && git config user.email t@e.com && git config user.name t && cp -r "$d/.factory" . )
export OPFX_ROOT="$wt"; export GH_LOG=$(mktemp); export OPFX_CHANGE=1-a
assert_exit 0 "disjoint requirements auto-merge" -- bash "$C" 1
assert_json '.merged' true "$OUT" "merged"; assert_json '.specsValid' true "$OUT" "specs valid"; assert_json '.archivedValid' true "$OUT" "archived valid"; assert_json '.ci' skipped "$OUT" "ci skipped (wait_ci false)"
[ "$(grep -c '^### Requirement' "$wt/openspec/specs/todo-list/spec.md")" = "2" ] && echo "  ok   both requirements present" || { echo "  FAIL union"; FAILS=$((FAILS+1)); }
assert_json '.pushed' true "$OUT" "merge commit pushed by check-pr"
assert_eq "$(cd "$wt" && git rev-parse HEAD)" "$(git -C "$bare" rev-parse factory/1-a)" "origin/factory/1-a is the merged head"
# wait_ci: no workflows → skipped; workflows + checks pass → pass (CI is watched after the push); checks fail → fail; no checks ever reported → none
jq '.gates.wait_ci=true' "$wt/.factory/config.json" > "$wt/.factory/c.json" && mv "$wt/.factory/c.json" "$wt/.factory/config.json"
assert_exit 0 "wait_ci without workflows" -- bash "$C" 1; assert_json '.ci' skipped "$OUT" "ci skipped when the repo has no workflows"
mkdir -p "$wt/.github/workflows"; : > "$wt/.github/workflows/test.yml"
assert_exit 0 "wait_ci checks pass" -- env GH_STUB_CHECKS_EXIT=0 bash "$C" 1; assert_json '.ci' pass "$OUT" "ci pass"
grep -q '^pr checks 1 --watch' "$GH_LOG" && echo "  ok   watched the PR checks" || { echo "  FAIL no watch"; FAILS=$((FAILS+1)); }
assert_exit 1 "wait_ci checks fail" -- env GH_STUB_CHECKS_EXIT=1 GH_STUB_CHECKS_OUT="X  test  fail" bash "$C" 1; assert_json '.ci' fail "$OUT" "ci fail"; assert_json '.ok' false "$OUT" "ok false on ci fail"
assert_exit 0 "wait_ci but no checks ever reported" -- env GH_STUB_CHECKS_EXIT=1 GH_STUB_CHECKS_OUT="no checks reported on the 'factory/1-a' branch" OPFX_CI_RETRIES=2 OPFX_CI_INTERVAL=0 bash "$C" 1; assert_json '.ci' none "$OUT" "ci none when no checks appear"
# branch C: MODIFIES 'todo の一覧' with different text, from the commit before 2-b → same requirement on both sides
( cd "$d" && git checkout -q -b factory/3-c HEAD~1 )
( cd "$d" && $FIX_OPENSPEC new change 3-c >/dev/null 2>&1; c=openspec/changes/3-c; mkdir -p $c/specs/todo-list
  printf '# Proposal\n\n## Why\n\n並びを古い順に固定したい。理由は監査のためで、この文は五十字を超えるように書いてある。\n\n## What Changes\n\n- x\n\n## Capabilities\n\n### New Capabilities\n\n### Modified Capabilities\n- `todo-list`: x\n\n## Impact\n\nx\n' > $c/proposal.md
  printf '# Spec Delta\n\n## MODIFIED Requirements\n\n### Requirement: todo の一覧\nThe system SHALL 登録済みの todo を古い順に返す。\n\n#### Scenario: 空のとき\n- **WHEN** todo が 1 件も無い\n- **THEN** 空の一覧を返す\n\n#### Scenario: 2 件あるとき\n- **WHEN** todo が 2 件ある\n- **THEN** 古い順に 2 件を返す\n' > $c/specs/todo-list/spec.md
  printf '# Tasks\n\n## 1. a\n\n- [x] 1.1 done\n' > $c/tasks.md
  $FIX_OPENSPEC archive 3-c --yes --json >/dev/null; git add -A; git commit -qm "archive 3-c"; git push -q origin factory/3-c )
wt2=$(mktemp -d); rm -rf "$wt2"; git clone -q "$bare" "$wt2"; ( cd "$wt2" && git checkout -q factory/3-c && git config user.email t@e.com && git config user.name t && cp -r "$d/.factory" . )
export OPFX_ROOT="$wt2"; export OPFX_CHANGE=3-c
assert_exit 1 "test_checkpr_same_requirement_escalates" -- bash "$C" 3
assert_json '.conflicts[0].kind' same-requirement "$OUT" "kind"
assert_json '.conflicts[0].requirements[0]' "todo の一覧" "$OUT" "requirement named"
( cd "$wt2" && git status --porcelain | grep -q '^UU' ) && { echo "  FAIL merge left in progress"; FAILS=$((FAILS+1)); } || echo "  ok   merge aborted"
# branch D and main both ADD '同じ題名' (different bodies) → must be same-requirement, not union-merged
( cd "$d" && git checkout -q main && git pull -q origin main )
mk_added() { # <name> <then-text>
  ( cd "$d" && $FIX_OPENSPEC new change "$1" >/dev/null 2>&1; c=openspec/changes/$1; mkdir -p $c/specs/todo-list
    printf '# Proposal\n\n## Why\n\n同じ題名を両側で足す試験。この文は五十字を超えるように少し長めに書いてある。\n\n## What Changes\n\n- x\n\n## Capabilities\n\n### New Capabilities\n\n### Modified Capabilities\n- `todo-list`: x\n\n## Impact\n\nx\n' > $c/proposal.md
    printf '# Spec Delta\n\n## ADDED Requirements\n\n### Requirement: 同じ題名\nThe system SHALL %s。\n\n#### Scenario: 例\n- **WHEN** x\n- **THEN** %s\n' "$2" "$2" > $c/specs/todo-list/spec.md
    printf '# Tasks\n\n## 1. a\n\n- [x] 1.1 done\n' > $c/tasks.md
    $FIX_OPENSPEC archive "$1" --yes --json >/dev/null; git add -A; git commit -qm "archive $1" )
}
( cd "$d" && git checkout -q -b factory/4-d ); mk_added 4-d "本文その一"; ( cd "$d" && git push -q origin factory/4-d )
( cd "$d" && git checkout -q main ); mk_added 5-e "本文その二"; ( cd "$d" && git push -q origin main )
wt3=$(mktemp -d); rmdir "$wt3"; git clone -q "$bare" "$wt3"; ( cd "$wt3" && git checkout -q factory/4-d && git config user.email t@e.com && git config user.name t && cp -r "$d/.factory" . )
export OPFX_ROOT="$wt3"; export OPFX_CHANGE=4-d; before=$(cd "$wt3" && git rev-parse HEAD)
assert_exit 1 "ADDED-vs-ADDED of the same header escalates" -- bash "$C" 4
assert_json '.conflicts[0].kind' same-requirement "$OUT" "kind for added-vs-added"
assert_json '.conflicts[0].requirements[0]' "同じ題名" "$OUT" "header named"
assert_eq "$before" "$(cd "$wt3" && git rev-parse HEAD)" "no merge commit left on a red gate"
# branch F and main both CREATE openspec/specs/todo-due/spec.md (different requirements): no base to union from → both-added, never a double preamble
mk_newcap() { # <name> <req-title>
  ( cd "$d" && $FIX_OPENSPEC new change "$1" >/dev/null 2>&1; c=openspec/changes/$1; mkdir -p $c/specs/todo-due
    printf '# Proposal\n\n## Why\n\n新しい能力を両側で作る試験。この文は五十字を超えるように少し長めに書いてある。\n\n## What Changes\n\n- x\n\n## Capabilities\n\n### New Capabilities\n- `todo-due`: x\n\n### Modified Capabilities\n\n## Impact\n\nx\n' > $c/proposal.md
    printf '# Spec Delta\n\n## ADDED Requirements\n\n### Requirement: %s\nThe system SHALL %s。\n\n#### Scenario: 例\n- **WHEN** x\n- **THEN** %s\n' "$2" "$2" "$2" > $c/specs/todo-due/spec.md
    printf '# Tasks\n\n## 1. a\n\n- [x] 1.1 done\n' > $c/tasks.md
    $FIX_OPENSPEC archive "$1" --yes --json >/dev/null; git add -A; git commit -qm "archive $1" )
}
( cd "$d" && git checkout -q main && git checkout -q -b factory/6-f ); mk_newcap 6-f "期限の表示"; ( cd "$d" && git push -q origin factory/6-f )
( cd "$d" && git checkout -q main ); mk_newcap 7-g "期限の通知"; ( cd "$d" && git push -q origin main )
wt4=$(mktemp -d); rmdir "$wt4"; git clone -q "$bare" "$wt4"; ( cd "$wt4" && git checkout -q factory/6-f && git config user.email t@e.com && git config user.name t && cp -r "$d/.factory" . )
export OPFX_ROOT="$wt4"; export OPFX_CHANGE=6-f; before=$(cd "$wt4" && git rev-parse HEAD)
assert_exit 1 "both sides creating the same capability file escalates" -- bash "$C" 6
assert_json '.conflicts[0].kind' both-added "$OUT" "kind for add/add"
assert_eq "$before" "$(cd "$wt4" && git rev-parse HEAD)" "no merge commit left on add/add"
finish
