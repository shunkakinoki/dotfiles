#!/usr/bin/env bash
set -u

ANTIGRAVITY_CLI_BIN="${ANTIGRAVITY_CLI_BIN:-${HOME}/.local/libexec/antigravity-cli/agy}"

traces_hooks_installed() {
  hooks_dir="$1/hooks"
  for hook in \
    post-commit \
    post-merge \
    pre-merge-commit \
    pre-push \
    traces-post-commit \
    traces-post-merge \
    traces-pre-merge-commit \
    traces-pre-push; do
    [ -x "$hooks_dir/$hook" ] || return 1
  done
}

if command -v git >/dev/null 2>&1 &&
  command -v traces >/dev/null 2>&1 &&
  [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]; then
  git_common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  if [ -n "$git_common_dir" ] &&
    ! traces_hooks_installed "$git_common_dir" &&
    ! traces setup git >/dev/null; then
    printf '%s\n' 'warning: unable to install Traces Git hooks; continuing with Antigravity CLI' >&2
  fi
fi

exec "$ANTIGRAVITY_CLI_BIN" "$@"
