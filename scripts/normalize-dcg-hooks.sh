#!/usr/bin/env bash
# shellcheck disable=SC2016 # The generated hook command must contain literal $HOME.
# Route every dcg hook command in an agent config through the tracked
# fail-closed wrapper.
#
# dcg's installer may emit a resolved path, a bare invocation, or a conditional
# lookup. All three degrade to an unguarded, non-blocking hook when dcg is
# missing, so rewrite them to config/shared/hooks/dcg-guard.sh instead.
#
# Usage: normalize-dcg-hooks.sh <hook_config> [hook_config ...]
set -euo pipefail

if (($# == 0)); then
  echo "usage: $0 <hook_config> [hook_config ...]" >&2
  exit 1
fi

for hook_config in "$@"; do
  if [[ ! -f $hook_config ]]; then
    echo "error: hook config not found: $hook_config" >&2
    exit 1
  fi

  tmp_file="$(mktemp "${hook_config}.tmp.XXXXXX")"
  if ! sed \
    -e 's|"command": "dcg"|"command": "$HOME/dotfiles/config/shared/hooks/dcg-guard.sh"|g' \
    -e 's|"command": "[^"[:space:]]*/dcg"|"command": "$HOME/dotfiles/config/shared/hooks/dcg-guard.sh"|g' \
    -e 's|"command": "command -v dcg >/dev/null 2>&1 && dcg"|"command": "$HOME/dotfiles/config/shared/hooks/dcg-guard.sh"|g' \
    -e 's|"command": "command -v dcg \\u003e/dev/null 2\\u003e\\u00261 \\u0026\\u0026 dcg"|"command": "$HOME/dotfiles/config/shared/hooks/dcg-guard.sh"|g' \
    "$hook_config" >"$tmp_file"; then
    rm -f "$tmp_file"
    exit 1
  fi

  if ! jq empty "$tmp_file"; then
    echo "error: dcg hook normalization produced invalid JSON: $hook_config" >&2
    rm -f "$tmp_file"
    exit 1
  fi

  if jq -e '
    .. | objects | .command? // empty
    | select(
        . == "command -v dcg >/dev/null 2>&1 && dcg"
        or test("(^|/)dcg$")
      )
  ' "$tmp_file" >/dev/null; then
    echo "error: unguarded dcg hook remains in $hook_config" >&2
    rm -f "$tmp_file"
    exit 1
  fi
  mv -f "$tmp_file" "$hook_config"
done
