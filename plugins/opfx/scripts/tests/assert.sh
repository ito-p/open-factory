#!/usr/bin/env bash
# Minimal assertions for opfx script tests. Source this.
FAILS=0
assert_eq() { if [ "$1" = "$2" ]; then echo "  ok   $3"; else echo "  FAIL $3: expected [$1] got [$2]"; FAILS=$((FAILS+1)); fi; }
assert_json() { local got; got=$(jq -rc "$1" <<<"$3"); assert_eq "$2" "$got" "$4"; }
# assert_exit <code> <label> -- <cmd...>; captures stdout into $OUT
assert_exit() { local want="$1" label="$2"; shift 3; set +e; OUT=$("$@" 2>/dev/null); local rc=$?; set -e; assert_eq "$want" "$rc" "$label (exit)"; }
finish() { if [ "$FAILS" -eq 0 ]; then echo "PASS $(basename "$0")"; else echo "FAIL $(basename "$0") ($FAILS)"; exit 1; fi; }
