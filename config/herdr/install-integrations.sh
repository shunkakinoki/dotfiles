#!/usr/bin/env bash
# Install Herdr's native Codex and OpenCode integrations.
# Usage: install-integrations.sh <herdr_bin>
set -euo pipefail

HERDR_BIN="${1:?Herdr executable required}"

status="$("$HERDR_BIN" integration status)"
for integration in codex opencode; do
  if printf '%s\n' "$status" | grep -q "^${integration}: current "; then
    continue
  fi
  "$HERDR_BIN" integration install "$integration"
done
