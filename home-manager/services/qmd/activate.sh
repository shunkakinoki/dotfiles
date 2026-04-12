#!/usr/bin/env bash
set -euo pipefail

QMD_BIN="$1"
WIKI_DIR="$2"

# Add wiki collection (idempotent - ignore if already exists)
"$QMD_BIN" collection add "$WIKI_DIR" 2>/dev/null || true
