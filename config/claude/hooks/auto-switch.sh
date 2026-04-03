#!/usr/bin/env bash
# Auto-switch Claude account on rate limit via claude-swap (cswap).
# Triggered by the StopFailure hook when Claude Code hits a rate limit.
#
# Reads hook input from stdin: { error, error_details, ... }
# Only switches if the error indicates a rate limit.

set -euo pipefail

# Require cswap
if ! command -v cswap &>/dev/null; then
  exit 0
fi

# Require at least 2 managed accounts
ACCOUNT_COUNT=$(cswap --list 2>/dev/null | grep -c '^\s*[0-9]' || echo 0)
if [ "$ACCOUNT_COUNT" -lt 2 ]; then
  exit 0
fi

# Read hook input from stdin
INPUT=$(cat)
ERROR=$(echo "$INPUT" | jq -r '.error // empty' 2>/dev/null) || true
ERROR_DETAILS=$(echo "$INPUT" | jq -r '.error_details // empty' 2>/dev/null) || true

# Check if the error is rate-limit related
case "${ERROR}${ERROR_DETAILS}" in
  *rate_limit*|*rate-limit*|*rate\ limit*|*overloaded*|*too_many_requests*|*429*|*quota*|*capacity*)
    echo "[$(date)] Auto-switching Claude account due to rate limit" >&2
    cswap --switch 2>&1 | head -5 >&2
    ;;
esac
