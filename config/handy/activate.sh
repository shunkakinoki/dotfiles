#!/usr/bin/env bash
# Copy Handy settings_store.json into the app's data dir.
# Handy writes to this file at runtime, so we cannot symlink to the
# read-only Nix store.
# Usage: activate.sh <settings_store_json>
set -euo pipefail
SETTINGS_JSON="$1"

case "$(uname -s)" in
  Darwin) DEST_DIR="$HOME/Library/Application Support/com.pais.handy" ;;
  Linux)  DEST_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/com.pais.handy" ;;
  *) echo "handy activate: unsupported OS $(uname -s)" >&2; exit 0 ;;
esac

mkdir -p "$DEST_DIR"
install -m 0644 "$SETTINGS_JSON" "$DEST_DIR/settings_store.json"
