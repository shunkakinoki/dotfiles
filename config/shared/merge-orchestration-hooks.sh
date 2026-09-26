#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq expressions intentionally contain $ variables.
# Register the orchestration prompt receipt in a harness's live hook config.
# JSON harnesses (claude, codex, devin) gain the rendered UserPromptSubmit
# entries; opencode takes the rendered plugin module at the target path.
# The renderer is consulted only at activation time.
# Usage: merge-orchestration-hooks.sh <harness> <target> <jq_bin> [orchestration_bin]
set -euo pipefail

HARNESS="${1:?harness required}"
TARGET="${2:?live hook target required}"
JQ_BIN="${3:?jq executable required}"
ORCHESTRATION_BIN="${4:-}"

# Lanes run from this checkout on every fleet host; hosts without it run no
# lanes and need no registration.
CANONICAL_ENTRYPOINT="$HOME/ghq/github.com/shunkakinokisoftware/shunkakinokisoftware/orchestration/cli/src/index.ts"

if [ -z "$ORCHESTRATION_BIN" ]; then
  ORCHESTRATION_BIN="$(PATH="$HOME/.local/bin:${PATH:-}" command -v orchestration 2>/dev/null || true)"
fi
if [ -z "$ORCHESTRATION_BIN" ] && [ -x "$CANONICAL_ENTRYPOINT" ]; then
  ORCHESTRATION_BIN="$CANONICAL_ENTRYPOINT"
fi
if [ -z "$ORCHESTRATION_BIN" ]; then
  exit 0
fi

# The renderer runs before the activation phase that puts Bun on PATH, and its
# shebang resolves Bun through env, so supply the interpreter directory here.
if ! rendered="$(PATH="$HOME/.bun/bin:$HOME/.local/bin:${PATH:-}" "$ORCHESTRATION_BIN" hooks render --harness "$HARNESS")"; then
  echo "error: failed to render live $HARNESS orchestration hooks" >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET")"
target_tmp="$(mktemp "${TARGET}.tmp.XXXXXX")"
trap 'rm -f "$target_tmp"' EXIT

if [ "$HARNESS" = "opencode" ]; then
  if [[ $rendered != *'"chat.message"'* ]]; then
    echo "error: orchestration returned invalid opencode plugin" >&2
    exit 1
  fi
  printf '%s\n' "$rendered" >"$target_tmp"
  chmod 644 "$target_tmp"
  mv -f "$target_tmp" "$TARGET"
  trap - EXIT
  exit 0
fi

if ! "$JQ_BIN" -e '
  (. | type) == "object"
  and (.hooks | type) == "object"
  and (.hooks.UserPromptSubmit | type) == "array"
' <<<"$rendered" >/dev/null; then
  echo "error: orchestration returned invalid $HARNESS hook configuration" >&2
  exit 1
fi

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
' "$TARGET" <(printf '%s\n' "$rendered") >"$target_tmp"; then
  echo "error: failed to merge live $HARNESS orchestration hooks" >&2
  exit 1
fi

if mode="$(stat -c '%a' "$TARGET" 2>/dev/null)" || mode="$(stat -f '%Lp' "$TARGET" 2>/dev/null)"; then
  chmod "$mode" "$target_tmp"
fi
mv -f "$target_tmp" "$TARGET"
trap - EXIT
