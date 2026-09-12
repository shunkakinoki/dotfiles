#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq expressions intentionally contain $ variables.
# Merge the optional orchestration prompt receipt into an existing live Codex
# hooks file. The renderer is intentionally consulted only at activation time.
# Usage: merge-orchestration-hooks.sh <hooks_json> <jq_bin> [orchestration_bin]
set -euo pipefail

HOOKS_JSON="${1:?live Codex hooks file required}"
JQ_BIN="${2:?jq executable required}"
ORCHESTRATION_BIN="${3:-}"

if [ -z "$ORCHESTRATION_BIN" ]; then
  ORCHESTRATION_BIN="$(PATH="$HOME/.local/bin:${PATH:-}" command -v orchestration 2>/dev/null || true)"
fi
if [ -z "$ORCHESTRATION_BIN" ]; then
  exit 0
fi

# The renderer runs before the activation phase that puts Bun on PATH, and its
# shebang resolves Bun through env, so supply the interpreter directory here.
if ! rendered="$(PATH="$HOME/.bun/bin:$HOME/.local/bin:${PATH:-}" "$ORCHESTRATION_BIN" hooks render --harness codex)"; then
  echo "error: failed to render live Codex orchestration hooks" >&2
  exit 1
fi
if ! "$JQ_BIN" -e '
  (. | type) == "object"
  and (.hooks | type) == "object"
  and (.hooks.UserPromptSubmit | type) == "array"
' <<<"$rendered" >/dev/null; then
  echo "error: orchestration returned invalid Codex hook configuration" >&2
  exit 1
fi

hooks_tmp="$(mktemp "${HOOKS_JSON}.tmp.XXXXXX")"
trap 'rm -f "$hooks_tmp"' EXIT
if ! "$JQ_BIN" -s '
  .[0] as $base
  | .[1] as $extra
  | ($base.hooks // {}) as $base_hooks
  | ($extra.hooks.UserPromptSubmit // []) as $extra_prompts
  | $base
  | .hooks = (
      $base_hooks
      | .UserPromptSubmit = (
          (.UserPromptSubmit // []) as $existing
          | reduce $extra_prompts[] as $hook
              ($existing;
                if any(.[]; . == $hook) then . else . + [$hook] end
              )
        )
    )
' "$HOOKS_JSON" <(printf '%s\n' "$rendered") >"$hooks_tmp"; then
  echo "error: failed to merge live Codex orchestration hooks" >&2
  exit 1
fi

if mode="$(stat -c '%a' "$HOOKS_JSON" 2>/dev/null)" || mode="$(stat -f '%Lp' "$HOOKS_JSON" 2>/dev/null)"; then
  chmod "$mode" "$hooks_tmp"
fi
mv -f "$hooks_tmp" "$HOOKS_JSON"
trap - EXIT
