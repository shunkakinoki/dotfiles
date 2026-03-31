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

  # Parse optional alias (path:alias)
  alias_name=""
  case "$line" in
  *:*)
    alias_name="${line##*:}"
    line="${line%:*}"
    ;;
  esac

  # Expand ~ to $HOME
  line="${line/#\~/$HOME}"

  # Skip library files silently (dependencies listed for update-local-binaries.sh)
  case "$line" in
  *.rlib | *.a | *.so | *.dylib) continue ;;
  esac

  # Check if binary exists and is executable
  if [ ! -f "$line" ] || [ ! -x "$line" ]; then
    echo "Skipping (not found or not executable): $line"
    continue
  fi

  # Get binary name and target path (use alias if provided)
  bin_name="${alias_name:-$(basename "$line")}"
  target="$BIN_DIR/$bin_name"

  # Walk up from binary to find a mise.toml (stops at $HOME)
  mise_dir=""
  walk="$(dirname "$line")"
  while [ "$walk" != "$HOME" ] && [ "$walk" != "/" ]; do
    if [ -f "$walk/mise.toml" ]; then
      mise_dir="$walk"
      break
    fi
    walk="$(dirname "$walk")"
  done

  # If a mise.toml was found and mise is available, create a wrapper script
  if [ -n "$mise_dir" ] && command -v mise >/dev/null 2>&1; then
    cat >"$target" <<WRAPPER
#!/usr/bin/env bash
exec mise exec -C "$mise_dir" -- "$line" "\$@"
WRAPPER
    chmod +x "$target"
    echo "Wrapped (mise): $bin_name -> $line (via $mise_dir/mise.toml)"
  else
    ln -sf "$line" "$target"
    echo "Linked: $bin_name -> $line"
  fi
done <"$BINARIES_FILE"
