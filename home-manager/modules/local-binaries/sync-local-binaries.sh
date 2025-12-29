#!/usr/bin/env bash

set -euo pipefail

# Sync local binaries from ~/.local-binaries.txt to ~/.local/bin
# Each line in the file should be an absolute path to a binary
# Lines starting with # are comments, empty lines are ignored

BINARIES_FILE="${HOME}/dotfiles/.local-binaries.txt"
BIN_DIR="${HOME}/.local/bin"

# Exit if no binaries file exists
if [ ! -f "$BINARIES_FILE" ]; then
  echo "No ${BINARIES_FILE} found, skipping local binaries sync"
  exit 0
fi

# Ensure bin directory exists
mkdir -p "$BIN_DIR"

# Process each line in the binaries file
while IFS= read -r line || [ -n "$line" ]; do
  # Trim leading and trailing whitespace
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"

  # Skip empty lines
  [ -z "$line" ] && continue

  # Skip comments
  case "$line" in
  \#*) continue ;;
  esac

  # Check if binary exists and is executable
  if [ ! -f "$line" ] || [ ! -x "$line" ]; then
    echo "Skipping (not found or not executable): $line"
    continue
  fi

  # Get binary name and create symlink
  bin_name="$(basename "$line")"
  target="$BIN_DIR/$bin_name"

  ln -sf "$line" "$target"
  echo "Linked: $bin_name -> $line"
done <"$BINARIES_FILE"
