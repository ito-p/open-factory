#!/usr/bin/env bash
# opfx shared helpers. Source this; do not execute.
set -euo pipefail

OPFX_OPENSPEC="${OPFX_OPENSPEC:-npx --yes @fission-ai/openspec@1.13.2}"
OPFX_ROOT="${OPFX_ROOT:-$(pwd)}"
OPFX_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '%s\n' "$*" >&2; }
json_out() { printf '%s\n' "$1"; }
die_usage() { log "usage: $*"; exit 2; }
require() { local c; for c in "$@"; do command -v "$c" >/dev/null 2>&1 || { log "missing command: $c"; exit 2; }; done; }

# openspec <args...> : pinned CLI, cwd = OPFX_ROOT
openspec() { ( cd "$OPFX_ROOT" && $OPFX_OPENSPEC "$@" ); }

# cfg <jq path> [default] : read .factory/config.json; prints default when file or key is missing
cfg() {
  local f="$OPFX_ROOT/.factory/config.json" d="${2:-}"
  if [ -f "$f" ]; then jq -r --arg d "$d" "($1) as \$v | if \$v == null then \$d else \$v end" "$f"; else printf '%s\n' "$d"; fi
}

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }
