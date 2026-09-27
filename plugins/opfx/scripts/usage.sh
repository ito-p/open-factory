#!/usr/bin/env bash
# Thin wrapper: token usage and cost estimate from Claude Code transcripts (see usage.mjs).
exec node "$(dirname "${BASH_SOURCE[0]}")/usage.mjs" "$@"
