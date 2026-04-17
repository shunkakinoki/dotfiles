#!/usr/bin/env bash
set -euo pipefail

SOURCE_JSON="$1"
TARGET_DIR="$HOME/.config/hyprpanel"
TARGET_JSON="$TARGET_DIR/config.json"
TMP_JSON="$TARGET_DIR/config.json.tmp"

mkdir -p "$TARGET_DIR"

if [ -L "$TARGET_JSON" ]; then
  rm -f "$TARGET_JSON"
fi

if [ -f "$TARGET_JSON" ] && cmp -s "$SOURCE_JSON" "$TARGET_JSON"; then
  exit 0
fi

cp -f "$SOURCE_JSON" "$TMP_JSON"
chmod 644 "$TMP_JSON"
mv -f "$TMP_JSON" "$TARGET_JSON"
