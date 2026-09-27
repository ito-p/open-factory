#!/usr/bin/env bash
source ./assert.sh
U="$(cd .. && pwd)/usage.sh"; F="$PWD/fixtures/usage-sample.jsonl"
export OPFX_PRICING="$PWD/fixtures/pricing-test.json"
cat > "$OPFX_PRICING" <<'PRICE'
{"asof":"2026-01-01","source":"test","per_mtok":{"claude-opus-5":{"input":5,"output":25,"cache_write_5m":6.25,"cache_write_1h":10,"cache_read":0.5}}}
PRICE
assert_exit 0 "sums" -- bash "$U" "$F"
assert_json '.total.in' 31 "$OUT" "test_usage_dedupes_request_id: input deduped (10+20+1)"
assert_json '.total.out' 106 "$OUT" "output"
assert_json '.total.cache_w' 1000 "$OUT" "cache write"
assert_json '.total.cache_r' 2000 "$OUT" "cache read"
# est = (31*5 + 106*25 + 1000*10 (1h) + 2000*0.5)/1e6 = (155+2650+10000+1000)/1e6 = 0.013805
assert_json '.total.est_usd' 0.013805 "$OUT" "estimate uses 1h cache-write rate"
assert_exit 0 "window" -- bash "$U" "$F" --since 2026-09-26T10:04:00Z --until 2026-09-26T10:59:00Z
assert_json '.total.in' 20 "$OUT" "since/until"
assert_exit 0 "line" -- bash "$U" "$F" --role worker --change 42-x --phase apply --line
case "$OUT" in "worker 42-x | phase=apply | model=claude-opus-5 | in=31 out=106 cache_w=1,000 cache_r=2,000 | est=\$0.0138 |"*) echo "  ok   line format";; *) echo "  FAIL line: $OUT"; FAILS=$((FAILS+1));; esac
case "$OUT" in *"| tools=2") echo "  ok   tool_use counted across records of one request";; *) echo "  FAIL tools count: $OUT"; FAILS=$((FAILS+1));; esac
home=$(mktemp -d); enc="-Users-me-ghq-github-com-me-my-app"; mkdir -p "$home/.claude/projects/$enc"; cp "$F" "$home/.claude/projects/$enc/s1.jsonl"
assert_exit 0 "--session with a dotted path" -- env HOME="$home" OPFX_ROOT="/Users/me/ghq/github.com/me/my.app" bash "$U" --session
assert_json '.total.in' 31 "$OUT" "session transcript found (non-alnum encoded as -)"
assert_exit 2 "missing file" -- bash "$U" /nonexistent.jsonl
finish
