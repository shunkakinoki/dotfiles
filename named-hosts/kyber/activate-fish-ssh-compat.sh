#!/usr/bin/env bash
# Persist Fish's terminal-query compatibility flag for Kyber SSH sessions.
# shellcheck disable=SC2016 # Fish expands $fish_features in the -c program.
set -euo pipefail

FISH_BIN="${1:?fish binary required}"

exec "$FISH_BIN" -c '
    if not contains -- no-query-term $fish_features
        set --universal --append fish_features no-query-term
    end
'
