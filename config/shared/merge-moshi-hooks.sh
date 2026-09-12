#!/usr/bin/env bash
# Merge a generated Moshi hook fragment into a hand-maintained agent config and
# print the result on stdout.
#
# `generated/hooks/moshi/<agent>` only carries Moshi hook entries; the rest of
# each agent's configuration lives under `config/<agent>`. Activation stitches
# the two halves back together so the live file stays a single document.
#
# Every supported agent stores hooks as `.hooks.<Event>` arrays, so merging is a
# per-event append that skips entries already present in the base config.
#
# Usage: merge-moshi-hooks.sh <base_json> <moshi_fragment_json> [jq_bin]
set -euo pipefail

BASE_JSON="${1:?base agent config required}"
FRAGMENT_JSON="${2:?moshi hook fragment required}"
JQ_BIN="${3:-jq}"

# shellcheck disable=SC2016 # $base/$fragment/$event/$hook are jq variables.
if ! "$JQ_BIN" -s '
  .[0] as $base
  | .[1] as $fragment
  | $base
  | .hooks = (
      reduce (($fragment.hooks // {}) | to_entries[]) as $event
        (($base.hooks // {});
          .[$event.key] = (
            reduce $event.value[] as $hook
              ((.[$event.key] // []);
                if any(.[]; . == $hook) then . else . + [$hook] end)
          )
        )
    )
' "$BASE_JSON" "$FRAGMENT_JSON"; then
  echo "error: failed to merge $FRAGMENT_JSON into $BASE_JSON" >&2
  exit 1
fi
