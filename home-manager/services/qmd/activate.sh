#!/usr/bin/env bash
set -euo pipefail

QMD_BIN="$1"
WIKI_DIR="$2"

# Add wiki collection only if not already registered
if ! "$QMD_BIN" collection list 2>/dev/null | grep -qF "$WIKI_DIR"; then
  "$QMD_BIN" collection add "$WIKI_DIR" 2>/dev/null || true
fi
