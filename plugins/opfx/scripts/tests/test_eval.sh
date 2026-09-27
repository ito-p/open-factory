#!/usr/bin/env bash
source ./assert.sh; source ./fixture.sh
E="$(cd .. && pwd)/eval.sh"
d=$(make_fixture); export OPFX_ROOT="$d"
jq '.gates.test_command="true" | .gates.lint_command="echo lint-ok"' "$d/.factory/config.json" > "$d/c.json" && mv "$d/c.json" "$d/.factory/config.json"
mkdir -p "$d/.factory/evals"; printf '#!/usr/bin/env bash\necho "eval saw $1"\n' > "$d/.factory/evals/10-first.sh"; chmod +x "$d/.factory/evals/10-first.sh"
printf '#!/usr/bin/env bash\nexit 3\n' > "$d/.factory/evals/20-fail.sh"; chmod +x "$d/.factory/evals/20-fail.sh"
printf 'not executable\n' > "$d/.factory/evals/30-skip.sh"
assert_exit 1 "stops at failing eval" -- bash "$E" c1
assert_json '.steps | length' 4 "$OUT" "test, lint, first, fail = 4 steps"
assert_json '.steps[2].tail' "eval saw c1" "$OUT" "change passed as \$1 (trailing newline stripped by \$(...))"
assert_json '.steps[3].exit' 3 "$OUT" "exit code kept"
rm "$d/.factory/evals/20-fail.sh"
assert_exit 0 "all green" -- bash "$E" c1
assert_json '.ok' true "$OUT" "ok"
jq '.gates.test_command="false"' "$d/.factory/config.json" > "$d/c.json" && mv "$d/c.json" "$d/.factory/config.json"
assert_exit 1 "failing test command" -- bash "$E" c1
assert_json '.steps | length' 1 "$OUT" "stops after test"
finish
