#!/usr/bin/env bash
set -u

ANTIGRAVITY_CLI_BIN="${ANTIGRAVITY_CLI_BIN:-${HOME}/.local/libexec/antigravity-cli/agy}"

# T3 validates the basename as `agy` and invokes this launcher directly. The
# CLIProxy instance is identified by its injected key; route that invocation
# to the proxy endpoint without changing native OAuth sessions.
CLIPROXY_KEY="${CLIPROXY_API_KEY:-${GEMINI_API_KEY:-}}"
if [ -n "$CLIPROXY_KEY" ]; then
  export CLIPROXY_API_KEY="$CLIPROXY_KEY"
  export GEMINI_API_KEY="$CLIPROXY_KEY"
  # T3's Antigravity ACP path treats GOOGLE_API_KEY as a native Google API
  # credential and may bypass the configured proxy base URL. Keep only the
  # Gemini API-key route for CLIProxy.
  unset GOOGLE_API_KEY
  export GOOGLE_GEMINI_BASE_URL="${CLIPROXY_GEMINI_BASE_URL:-https://cliproxy.shunkakinoki.com/v1}"
fi

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
