#!/usr/bin/env bash
source ./assert.sh
d=$(mktemp -d); mkdir -p "$d/.factory"; echo '{"gates":{"max_retries":3,"wait_ci":false}}' > "$d/.factory/config.json"
export OPFX_ROOT="$d"; source ../lib.sh
assert_eq "3" "$(cfg '.gates.max_retries' 9)" "cfg reads value"
assert_eq "9" "$(cfg '.gates.missing' 9)" "cfg default on missing key"
assert_eq "false" "$(cfg '.gates.wait_ci' true)" "cfg returns a stored false instead of the default"
assert_exit 0 "openspec.sh runs the pinned OpenSpec (agents never hunt for a binary)" -- bash ../openspec.sh --version
case "$OUT" in *1.13.2*) echo "  ok   openspec.sh version 1.13.2";; *) echo "  FAIL openspec.sh version: $OUT"; FAILS=$((FAILS+1));; esac
OPFX_ROOT="/nonexistent"; assert_eq "x" "$(cfg '.a' x)" "cfg default on missing file"
finish
