#!/usr/bin/env bash
set -euo pipefail

QMD_BIN="$1"
WIKI_DIR="$2"

# Bun skips postinstall scripts for global installs, so better-sqlite3's
# native addon never gets built. Rebuild it if the .node binary is missing.
SQLITE_DIR="$HOME/.bun/install/global/node_modules/better-sqlite3"
if [ -d "$SQLITE_DIR" ] && [ ! -f "$SQLITE_DIR/build/Release/better_sqlite3.node" ]; then
  (cd "$SQLITE_DIR" && npm run install) 2>&1 || true
fi

# Add wiki collection if not already present
if ! "$QMD_BIN" collection list 2>/dev/null | grep -q "wiki"; then
  "$QMD_BIN" collection add "$WIKI_DIR"
fi
