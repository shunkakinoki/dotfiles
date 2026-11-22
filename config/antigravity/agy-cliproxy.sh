#!/usr/bin/env bash
set -euo pipefail

: "${CLIPROXY_API_KEY:?Set CLIPROXY_API_KEY in ~/dotfiles/.env before using agy-cliproxy}"
export GEMINI_API_KEY="$CLIPROXY_API_KEY"
export GEMINI_BASE_URL="${CLIPROXY_GEMINI_BASE_URL:-https://cliproxy.shunkakinoki.com/v1}"
exec "${HOME}/.local/bin/agy" "$@"
