#!/usr/bin/env bash
source ./assert.sh; source ./fixture.sh
A="$(cd .. && pwd)/archive.sh"
d=$(make_fixture); export OPFX_ROOT="$d"
add_change "$d" c-open tasks-open; add_change "$d" c-done tasks-done; add_change "$d" c-nf modified-notfound
assert_exit 1 "test_archive_refuses_incomplete" -- bash "$A" c-open
assert_json '.code' tasks_incomplete "$OUT" "code tasks_incomplete"
[ -d "$d/openspec/changes/c-open" ] && echo "  ok   change still active" || { echo "  FAIL archived despite open task"; FAILS=$((FAILS+1)); }
assert_exit 1 "archive refusal passes through" -- bash "$A" c-nf
assert_json '.code' archive_spec_update_failed "$OUT" "openspec code kept"
assert_exit 0 "complete change archives" -- bash "$A" c-done
assert_json '.archivedAs | endswith("-c-done")' true "$OUT" "archivedAs"
assert_exit 1 "unknown change" -- bash "$A" nope
assert_json '.code' change_not_found "$OUT" "code change_not_found"
finish
