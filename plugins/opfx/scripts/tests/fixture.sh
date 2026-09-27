#!/usr/bin/env bash
# Builds a throwaway product repo with OpenSpec initialised. Source it.
FIX_OPENSPEC="${OPFX_OPENSPEC:-npx --yes @fission-ai/openspec@1.13.2}"

_write_change_base() { # <dir> <name> <capability>
  local c="$1/openspec/changes/$2"; mkdir -p "$c/specs/$3"
  printf '# Proposal\n\n## Why\n\n%s を変えたい。理由はこの試験で挙動を確かめるためであり、五十字を超える説明を置く。\n\n## What Changes\n\n- x\n\n## Capabilities\n\n### New Capabilities\n\n### Modified Capabilities\n- `%s`: x\n\n## Impact\n\nx\n' "$3" "$3" > "$c/proposal.md"
}

# make_fixture : prints the path of a fresh product repo (git, openspec init, one archived capability todo-list, .factory/config.json)
make_fixture() {
  local d; d=$(mktemp -d); ( cd "$d" && git init -q . && git config user.email t@example.com && git config user.name t
    $FIX_OPENSPEC init --tools claude --language ja --no-animation . >/dev/null 2>&1
    mkdir -p .factory && cat > .factory/config.json <<'EOF'
{"base_branch":"main","language":"ja","orchestration":{"workers":2,"review_parallel":2,"batch_size":5},
 "models":{"worker":"opus","reviewer":"opus","handler":"opus"},
 "review":{"max_rounds":2,"stop_on":["CRITICAL","QUESTION"],"fix_before_human":["CRITICAL","WARNING"],"fix_before_merge":["CRITICAL"],"contest_allowed":1},
 "gates":{"max_retries":3,"test_command":"","lint_command":"","wait_ci":false},
 "escalation":{"on":["a","b","c","d","e","f"]},
 "labels":{"queued":"#C5C5C5","proposed":"#5BA3E6","review":"#8B5CF6","approved":"#1D76DB","pr":"#0B4F9C","blocked":"#F0883E","done":"#2EA043","follow-up":"#FBCA04"}}
EOF
    $FIX_OPENSPEC new change seed-list >/dev/null 2>&1
    local c=openspec/changes/seed-list; mkdir -p $c/specs/todo-list
    printf '# Proposal\n\n## Why\n\ntodo を一覧できないと確かめられない。この文は五十字を超えるように長めに書いてある。\n\n## What Changes\n\n- list\n\n## Capabilities\n\n### New Capabilities\n- `todo-list`: 一覧\n\n### Modified Capabilities\n\n## Impact\n\nlist\n' > $c/proposal.md
    printf '# Spec Delta\n\n## Purpose\n\n利用者が登録した todo を並べて確かめられるようにする能力を定める。五十字以上の説明。\n\n## ADDED Requirements\n\n### Requirement: todo の一覧\nThe system SHALL 登録済みの todo を登録順に返す。\n\n#### Scenario: 空のとき\n- **WHEN** todo が 1 件も無い\n- **THEN** 空の一覧を返す\n\n#### Scenario: 2 件あるとき\n- **WHEN** todo が 2 件ある\n- **THEN** 登録順に 2 件を返す\n' > $c/specs/todo-list/spec.md
    printf '# Tasks\n\n## 1. a\n\n- [x] 1.1 一覧を足し、試験が通ることを確かめる\n' > $c/tasks.md
    $FIX_OPENSPEC archive seed-list --yes --json >/dev/null 2>&1
    git add -A && git commit -q -m seed )
  echo "$d"
}

# add_change <dir> <name> <kind> : kind = added-ok | modified-partial | modified-notfound | tasks-open | tasks-done
add_change() {
  local d="$1" n="$2" k="$3"
  ( cd "$d" && $FIX_OPENSPEC new change "$n" >/dev/null 2>&1 )
  local c="$d/openspec/changes/$n"; mkdir -p "$c/specs/todo-list"
  _write_change_base "$d" "$n" todo-list
  case "$k" in
    added-ok)
      printf '# Spec Delta\n\n## ADDED Requirements\n\n### Requirement: 新しい順の一覧\nThe system SHALL 登録済みの todo を新しい順に返す。\n\n#### Scenario: 2 件あるとき\n- **WHEN** todo が 2 件ある\n- **THEN** 新しい順に 2 件を返す\n' > "$c/specs/todo-list/spec.md"
      printf '# Tasks\n\n## 1. a\n\n- [x] 1.1 done\n' > "$c/tasks.md" ;;
    modified-partial)
      printf '# Spec Delta\n\n## MODIFIED Requirements\n\n### Requirement: todo の一覧\nThe system SHALL 登録済みの todo を新しい順に返す。\n\n#### Scenario: 2 件あるとき\n- **WHEN** todo が 2 件ある\n- **THEN** 新しい順に 2 件を返す\n' > "$c/specs/todo-list/spec.md"
      printf '# Tasks\n\n## 1. a\n\n- [x] 1.1 done\n' > "$c/tasks.md" ;;
    modified-notfound)
      printf '# Spec Delta\n\n## MODIFIED Requirements\n\n### Requirement: todo 一覧\nThe system SHALL 登録済みの todo を新しい順に返す。\n\n#### Scenario: 空のとき\n- **WHEN** todo が 1 件も無い\n- **THEN** 空の一覧を返す\n\n#### Scenario: 2 件あるとき\n- **WHEN** todo が 2 件ある\n- **THEN** 新しい順に 2 件を返す\n' > "$c/specs/todo-list/spec.md"
      printf '# Tasks\n\n## 1. a\n\n- [x] 1.1 done\n' > "$c/tasks.md" ;;
    tasks-open)
      printf '# Spec Delta\n\n## ADDED Requirements\n\n### Requirement: 期限つきの一覧\nThe system SHALL 期限の近い順に返す。\n\n#### Scenario: 2 件あるとき\n- **WHEN** 期限の違う todo が 2 件ある\n- **THEN** 期限の近い順に返す\n' > "$c/specs/todo-list/spec.md"
      printf '# Tasks\n\n## 1. a\n\n- [ ] 1.1 open\n- [x] 1.2 done\n' > "$c/tasks.md" ;;
    tasks-done)
      printf '# Spec Delta\n\n## ADDED Requirements\n\n### Requirement: 期限つきの一覧\nThe system SHALL 期限の近い順に返す。\n\n#### Scenario: 2 件あるとき\n- **WHEN** 期限の違う todo が 2 件ある\n- **THEN** 期限の近い順に返す\n' > "$c/specs/todo-list/spec.md"
      printf '# Tasks\n\n## 1. a\n\n- [x] 1.1 done\n- [x] 1.2 done\n' > "$c/tasks.md" ;;
    no-shall)
      printf '# Spec Delta\n\n## ADDED Requirements\n\n### Requirement: 重複の拒否\nThe system は重複した題名の todo を拒む。\n\n#### Scenario: 同じ題名\n- **WHEN** 同じ題名の todo を足す\n- **THEN** 拒む\n' > "$c/specs/todo-list/spec.md"
      printf '# Tasks\n\n## 1. a\n\n- [x] 1.1 done\n' > "$c/tasks.md" ;;
    *) echo "unknown kind $k" >&2; return 2 ;;
  esac
  ( cd "$d" && git add -A && git commit -q -m "add $n" )
}
