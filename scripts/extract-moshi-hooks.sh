#!/usr/bin/env bash
# Extract the Moshi-only hook entries from a live agent config.
#
# `generated/hooks` is reserved for machine-generated adapters: Moshi hooks
# under `generated/hooks/moshi` and Traces hooks under `generated/hooks/traces`.
# Everything else an agent needs (permissions, env, MCP servers, the shared
# security hooks, Traces entries) is hand-maintained under `config/<agent>` and
# is merged back in at activation time by config/shared/merge-moshi-hooks.sh.
#
# Usage: extract-moshi-hooks.sh <live_config> <moshi_fragment_out>
set -euo pipefail

LIVE_CONFIG="${1:?live agent config required}"
FRAGMENT_OUT="${2:?moshi fragment output path required}"

read -r -d '' MOSHI_DEFS <<'JQ' || true
def cmds: [.. | objects | .command? // empty | select(type == "string")];
def is_moshi: (cmds | length > 0 and all(test("moshi-hook")));
JQ

mkdir -p "$(dirname "$FRAGMENT_OUT")"

# A hook entry belongs to Moshi only when every command it carries invokes
# moshi-hook. A mixed entry would drag unrelated commands into the generated
# fragment, so fail loudly instead of guessing.
if jq -e "$MOSHI_DEFS"'
  (.hooks // {})
  | to_entries[]
  | .value[]
  | select((cmds | length) > 0)
  | select((cmds | any(test("moshi-hook"))) and (cmds | any(test("moshi-hook") | not)))
' "$LIVE_CONFIG" >/dev/null; then
  echo "error: $LIVE_CONFIG mixes moshi and non-moshi commands in one hook entry" >&2
  exit 1
fi

fragment_tmp="$(mktemp "${FRAGMENT_OUT}.tmp.XXXXXX")"
trap 'rm -f "$fragment_tmp"' EXIT

jq -S --indent 2 "$MOSHI_DEFS"'
  { hooks: (
      (.hooks // {})
      | map_values(map(select(is_moshi)))
      | with_entries(select(.value | length > 0))
    )
  }
' "$LIVE_CONFIG" >"$fragment_tmp"

mv -f "$fragment_tmp" "$FRAGMENT_OUT"
trap - EXIT
