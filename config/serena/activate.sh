#!/usr/bin/env bash
# Copy Serena config if missing or is a symlink
# Usage: activate.sh <source> <dest>
set -euo pipefail
SRC="$1"
DEST="$2"

mkdir -p "$(dirname "$DEST")"
if [ ! -f "$DEST" ] || [ -L "$DEST" ]; then
  rm -f "$DEST"
  cp "$SRC" "$DEST"
  chmod u+w "$DEST"
fi
