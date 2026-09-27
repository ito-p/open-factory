#!/usr/bin/env bash
# Runs the pinned OpenSpec CLI in OPFX_ROOT: agents call this instead of a bare `openspec` (there is no global binary to find).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
openspec "$@"
