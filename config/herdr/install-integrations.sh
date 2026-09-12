#!/usr/bin/env bash
# Install Herdr's native Codex and OpenCode integrations.
# Usage: install-integrations.sh <herdr_bin>
set -euo pipefail

HERDR_BIN="${1:?Herdr executable required}"

"$HERDR_BIN" integration install codex
"$HERDR_BIN" integration install opencode
