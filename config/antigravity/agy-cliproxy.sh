#!/usr/bin/env bash
set -euo pipefail

# T3 validates custom executables before it supplies provider environment. Keep
# metadata probes credential-free; real sessions still require the API key.
case "${1:-}" in
  --version|--help|-h)
    exec "${HOME}/.local/bin/agy" "$@"
    ;;
esac

: "${CLIPROXY_API_KEY:?Set CLIPROXY_API_KEY in ~/dotfiles/.env before using agy-cliproxy}"
export GEMINI_API_KEY="$CLIPROXY_API_KEY"
export GEMINI_BASE_URL="${CLIPROXY_GEMINI_BASE_URL:-https://cliproxy.shunkakinoki.com/v1}"
exec "${HOME}/.local/bin/agy" "$@"
