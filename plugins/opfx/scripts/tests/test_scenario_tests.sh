#!/usr/bin/env bash
source ./assert.sh; source ./fixture.sh
E="$(cd ../../templates/evals && pwd)/scenario-tests.sh"
d=$(make_fixture); add_change "$d" 9-s added-ok   # delta has Scenario "2 件あるとき"
assert_exit 1 "scenario without a test is red" -- bash -c "cd '$d' && bash '$E' 9-s"
mkdir -p "$d/test"; printf 'it("2 件あるとき", () => {});\n' > "$d/test/x.test.ts"
assert_exit 0 "scenario named in a test passes" -- bash -c "cd '$d' && bash '$E' 9-s"
( cd "$d" && $FIX_OPENSPEC archive 9-s --yes --json >/dev/null 2>&1 )
[ -d "$d/openspec/changes/9-s" ] && { echo "  FAIL fixture: change still active"; FAILS=$((FAILS+1)); } || echo "  ok   change archived"
assert_exit 0 "after archive the archived delta is read" -- bash -c "cd '$d' && bash '$E' 9-s"
rm "$d/test/x.test.ts"
mkdir -p "$d/web/test"; printf 'it("2 件あるとき", () => {});\n' > "$d/web/test/x.test.ts"
assert_exit 0 "a test inside a workspace (web/test) counts" -- bash -c "cd '$d' && bash '$E' 9-s"
mkdir -p "$d/node_modules/pkg"; printf '2 件あるとき\n' > "$d/node_modules/pkg/readme.md"; rm "$d/web/test/x.test.ts"
assert_exit 1 "node_modules does not count" -- bash -c "cd '$d' && bash '$E' 9-s"
assert_exit 1 "after archive a missing test is still red (not zero scenarios → green)" -- bash -c "cd '$d' && bash '$E' 9-s"
assert_exit 1 "unknown change is red" -- bash -c "cd '$d' && bash '$E' nope"
# a change with skip_specs has no delta by design: green, not "no delta specs"
mkdir -p "$d/openspec/changes/10-docs"; printf 'schema: spec-driven\nskip_specs: true\n' > "$d/openspec/changes/10-docs/.openspec.yaml"
assert_exit 0 "skip_specs change (active) passes" -- bash -c "cd '$d' && bash '$E' 10-docs"
mkdir -p "$d/openspec/changes/archive/2026-09-28-11-docs"; printf 'schema: spec-driven\nskip_specs: true\n' > "$d/openspec/changes/archive/2026-09-28-11-docs/.openspec.yaml"
assert_exit 0 "skip_specs change (archived) passes" -- bash -c "cd '$d' && bash '$E' 11-docs"
finish
