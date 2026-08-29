#!/usr/bin/env bash
set -u

ANTIGRAVITY_CLI_BIN="${ANTIGRAVITY_CLI_BIN:-${HOME}/.local/libexec/antigravity-cli/agy}"

if command -v git >/dev/null 2>&1 &&
  command -v traces >/dev/null 2>&1 &&
  git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if ! traces setup git >/dev/null; then
    printf '%s\n' 'warning: unable to install Traces Git hooks; continuing with Antigravity CLI' >&2
  fi
fi

exec "$ANTIGRAVITY_CLI_BIN" "$@"
