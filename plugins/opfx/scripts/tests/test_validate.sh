#!/usr/bin/env bash
source ./assert.sh; source ./fixture.sh
V="$(cd .. && pwd)/validate.sh"
d=$(make_fixture); export OPFX_ROOT="$d"
add_change "$d" c-ok added-ok
add_change "$d" c-partial modified-partial
add_change "$d" c-notfound modified-notfound
assert_exit 0 "valid ADDED passes" -- bash "$V" c-ok
assert_json '.ok' true "$OUT" "ok true"
assert_exit 1 "partial MODIFIED is red" -- bash "$V" c-partial
assert_json '.red[0].level' ERROR "$OUT" "ERROR captured"
assert_exit 1 "test_validate_info_is_red: header not found (INFO) is red" -- bash "$V" c-notfound
assert_json '.valid' true "$OUT" "openspec said valid"
assert_json '.red[0].message | startswith("Archive would refuse")' true "$OUT" "INFO archive-would-refuse is red"
add_change "$d" c-noshall no-shall
assert_exit 1 "WARNING-only delta is red under --strict" -- bash "$V" c-noshall
assert_json '.red[0].level' WARNING "$OUT" "WARNING listed in red so the worker sees what to fix"
assert_exit 2 "usage error" -- bash "$V"
finish
