#!/usr/bin/env bash
source ./assert.sh
T="$(cd .. && pwd)/trace.sh"; export GH_LOG=$(mktemp); export OPFX_CHANGE=42-add-due-date
assert_exit 0 "phase comment" -- bash "$T" issue 42 phase propose
assert_json '.url' "https://github.com/stub/repo/issues/1#issuecomment-1" "$OUT" "url from gh"
grep -q '^issue comment 42 --body phase | 42-add-due-date | propose | 20' "$GH_LOG" && echo "  ok   phase body" || { echo "  FAIL phase body: $(cat "$GH_LOG")"; FAILS=$((FAILS+1)); }
f=$(mktemp); printf 'CRITICAL | R1-1 | specs/todo-list | missing scenario\n' > "$f"
assert_exit 0 "review comment on pr" -- bash "$T" pr 7 review R2 "$f"
grep -q '^pr comment 7 --body review | 42-add-due-date | R2 |' "$GH_LOG" && echo "  ok   review body" || { echo "  FAIL review body"; FAILS=$((FAILS+1)); }
assert_exit 0 "usage line" -- bash "$T" issue 42 usage "worker 42-add-due-date | phase=apply | model=m | in=1 out=2 cache_w=3 cache_r=4 | est=\$0.01"
grep -q -- '--body usage | worker 42-add-due-date | phase=apply' "$GH_LOG" && echo "  ok   usage body" || { echo "  FAIL usage body"; FAILS=$((FAILS+1)); }
root=$(mktemp -d); export OPFX_ROOT="$root"; export GH_CWD_LOG=$(mktemp)
assert_exit 0 "runs gh in OPFX_ROOT" -- bash -c "cd /tmp && bash '$T' issue 1 phase x"
assert_eq "$(cd "$root" && pwd -P)" "$(tail -n1 "$GH_CWD_LOG")" "gh cwd is OPFX_ROOT, not the caller cwd"
assert_exit 2 "bad target" -- bash "$T" wiki 1 phase x
assert_exit 2 "bad kind" -- bash "$T" issue 1 nope
assert_exit 2 "empty usage line is a usage error" -- bash "$T" issue 1 usage ""
assert_exit 0 "agent id recorded" -- bash "$T" issue 42 agent worker abc123
grep -q -- '--body agent | 42-add-due-date | worker | abc123 | 20' "$GH_LOG" && echo "  ok   agent body" || { echo "  FAIL agent body"; FAILS=$((FAILS+1)); }
assert_exit 2 "agent needs role and id" -- bash "$T" issue 42 agent worker
assert_exit 1 "gh failure still yields one JSON" -- env GH_STUB_FAIL=1 bash "$T" issue 42 phase apply
assert_json '.ok' false "$OUT" "ok false on gh failure"; assert_json '.error | length > 0' true "$OUT" "error text carried"
finish
