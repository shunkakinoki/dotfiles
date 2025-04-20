#!/usr/bin/env bash

# Base directories
VSCODE_USER_DIR="/Users/shunkakinoki/Library/Application Support/Code/User"
CURSOR_USER_DIR="/Users/shunkakinoki/Library/Application Support/Cursor/User"
WINDSURF_USER_DIR="/Users/shunkakinoki/Library/Application Support/Windsurf/User"

# Files to sync
SETTINGS_FILE="settings.json"
KEYBINDINGS_FILE="keybindings.json"

# Ensure target directories exist
mkdir -p "$CURSOR_USER_DIR"
mkdir -p "$WINDSURF_USER_DIR"

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

# Initial sync for both files
sync_files "$SETTINGS_FILE"
sync_files "$KEYBINDINGS_FILE"

# Watch for changes in both files
fswatch -o "$VSCODE_USER_DIR/$SETTINGS_FILE" "$VSCODE_USER_DIR/$KEYBINDINGS_FILE" | while read -r changed_file; do
  if [[ "$changed_file" == *"$SETTINGS_FILE" ]]; then
    sync_files "$SETTINGS_FILE"
  elif [[ "$changed_file" == *"$KEYBINDINGS_FILE" ]]; then
    sync_files "$KEYBINDINGS_FILE"
  fi
done 
