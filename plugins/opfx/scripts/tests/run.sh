#!/usr/bin/env bash
# Runs every test_*.sh in this directory with the gh stub first on PATH.
set -uo pipefail
cd "$(dirname "$0")"
export PATH="$PWD/stubs:$PATH"
export GH_LOG="${GH_LOG:-$(mktemp)}"
rc=0
for t in test_*.sh; do echo "== $t"; bash "$t" || rc=1; done
exit $rc
