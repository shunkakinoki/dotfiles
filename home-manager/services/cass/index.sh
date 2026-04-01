#!/usr/bin/env bash
set -euo pipefail

CASS="$HOME/.local/bin/cass"

if [ ! -x "$CASS" ]; then
  echo "cass binary not found at $CASS"
  exit 1
fi

echo "$(date): starting cass sync + index + analytics rebuild"

# Sync remote sources (ignore failures for unreachable hosts)
"$CASS" sources sync || true

# Full reindex
"$CASS" index --full

# Rebuild analytics rollup tables
"$CASS" analytics rebuild

echo "$(date): cass index + analytics rebuild complete"
