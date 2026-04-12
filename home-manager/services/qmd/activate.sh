#!/usr/bin/env bash
set -euo pipefail

QMD_BIN="$1"
WIKI_DIR="$2"

# Add wiki collection if not already present
if ! "$QMD_BIN" collection list 2>/dev/null | grep -q "wiki"; then
  "$QMD_BIN" collection add "$WIKI_DIR"
fi
