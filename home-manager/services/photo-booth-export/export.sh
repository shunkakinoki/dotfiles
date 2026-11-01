#!/usr/bin/env bash

set -euo pipefail

LIBRARY_DIR="$HOME/Pictures/Photo Booth Library/Pictures"
DESKTOP_DIR="$HOME/Desktop"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/photo-booth-export/exported"

[ -d "$LIBRARY_DIR" ] || exit 0

shopt -s nullglob

# Without a record of exported names, deleting a copy from the Desktop would
# bring it back. The first run records the existing library so years of old
# captures are not dumped onto the Desktop.
if [ ! -f "$STATE_FILE" ]; then
  mkdir -p "$(dirname "$STATE_FILE")"
  for file in "$LIBRARY_DIR"/*; do
    basename "$file"
  done >"$STATE_FILE"
  exit 0
fi

for file in "$LIBRARY_DIR"/*; do
  [ -f "$file" ] || continue
  name=$(basename "$file")
  grep -Fxq -- "$name" "$STATE_FILE" && continue

  # A movie can still be growing when the directory changes. Leave it for the
  # agent's next periodic run instead of exporting a truncated copy.
  size=$(wc -c <"$file")
  sleep 1
  [ "$size" -gt 0 ] && [ "$size" -eq "$(wc -c <"$file")" ] || continue

  if [ ! -e "$DESKTOP_DIR/$name" ]; then
    temp="$DESKTOP_DIR/.$name.tmp"
    cp -p "$file" "$temp"
    mv "$temp" "$DESKTOP_DIR/$name"
  fi
  printf '%s\n' "$name" >>"$STATE_FILE"
done
