#!/usr/bin/env bash
# Thin wrapper: reviewer rubric-verdict table → requirements JSON (see rubric-parse.mjs).
exec node "$(dirname "${BASH_SOURCE[0]}")/rubric-parse.mjs" "$@"
