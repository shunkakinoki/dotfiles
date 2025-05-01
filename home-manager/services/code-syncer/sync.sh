#!/usr/bin/env bash

# Base directories
VSCODE_USER_DIR="/Users/shunkakinoki/Library/Application Support/Code/User"
CURSOR_USER_DIR="/Users/shunkakinoki/Library/Application Support/Cursor/User"
WINDSURF_USER_DIR="/Users/shunkakinoki/Library/Application Support/Windsurf/User"

# Files to sync
SETTINGS_FILE="settings.json"
KEYBINDINGS_FILE="keybindings.json"
EXTENSIONS_FILE="extensions.list"

# Ensure target directories exist
mkdir -p "$CURSOR_USER_DIR"
mkdir -p "$WINDSURF_USER_DIR"

# Function to export VSCode extensions
export_extensions() {
  code --list-extensions >"$VSCODE_USER_DIR/$EXTENSIONS_FILE"
}

# Function to install extensions
install_extensions() {
  local target_editor=$1
  local cli_command

  case $target_editor in
  "cursor")
    cli_command="cursor"
    ;;
  "windsurf")
    cli_command="windsurf"
    ;;
  *)
    echo "Unknown editor: $target_editor"
    return 1
    ;;
  esac

  if [ -f "$VSCODE_USER_DIR/$EXTENSIONS_FILE" ]; then
    while IFS= read -r extension; do
      $cli_command --install-extension "$extension" >/dev/null 2>&1
    done <"$VSCODE_USER_DIR/$EXTENSIONS_FILE"
    echo "Extensions synced to $target_editor at $(date)"
  else
    echo "Extensions list not found"
  fi
}

# Function to sync files
sync_files() {
  local file=$1
  local source_path="$VSCODE_USER_DIR/$file"

  if [ -f "$source_path" ]; then
    cp "$source_path" "$CURSOR_USER_DIR/$file"
    cp "$source_path" "$WINDSURF_USER_DIR/$file"
    echo "$file synced at $(date)"
  else
    echo "VSCode $file not found"
  fi
}

# Function to sync everything
sync_all() {
  export_extensions
  sync_files "$SETTINGS_FILE"
  sync_files "$KEYBINDINGS_FILE"
  sync_files "$EXTENSIONS_FILE"
  install_extensions "cursor"
  install_extensions "windsurf"
}

# Initial sync for all files and extensions
sync_all

# Watch for changes in configuration files
echo "Starting to watch for changes in configuration files..."

fswatch -o "$VSCODE_USER_DIR/$SETTINGS_FILE" "$VSCODE_USER_DIR/$KEYBINDINGS_FILE" | while read -r changed_file; do
  if [[ $changed_file == *"$SETTINGS_FILE" ]]; then
    echo "Settings file changed, syncing..."
    sync_files "$SETTINGS_FILE"
  elif [[ $changed_file == *"$KEYBINDINGS_FILE" ]]; then
    echo "Keybindings file changed, syncing..."
    sync_files "$KEYBINDINGS_FILE"
  fi
done
