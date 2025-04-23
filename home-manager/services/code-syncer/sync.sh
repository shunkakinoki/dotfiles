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

# Function to sync extensions
sync_extensions() {
  echo "Starting extension sync..."
  local vscode_extensions
  local cursor_extensions
  local windsurf_extensions

  # Get installed extensions, handle potential errors if command fails
  vscode_extensions=$(code --list-extensions 2>/dev/null) || { echo "Failed to get VSCode extensions."; return 1; }
  cursor_extensions=$(cursor --list-extensions 2>/dev/null) || { echo "Failed to get Cursor extensions. Assuming none installed."; cursor_extensions=""; }
  windsurf_extensions=$(windsurf --list-extensions 2>/dev/null) || { echo "Failed to get Windsurf extensions. Assuming none installed."; windsurf_extensions=""; }

  # Sync to Cursor
  echo "Syncing extensions to Cursor..."
  for ext in $vscode_extensions; do
    # Check if the extension ID exists exactly in the list
    if ! echo "$cursor_extensions" | grep -Fxq "$ext"; then
      echo "Installing $ext in Cursor..."
      cursor --install-extension "$ext" --force || echo "Failed to install $ext in Cursor."
    fi
  done

  # Sync to Windsurf
  echo "Syncing extensions to Windsurf..."
  for ext in $vscode_extensions; do
    # Check if the extension ID exists exactly in the list
    if ! echo "$windsurf_extensions" | grep -Fxq "$ext"; then
      echo "Installing $ext in Windsurf..."
      windsurf --install-extension "$ext" --force || echo "Failed to install $ext in Windsurf."
    fi
  done
  echo "Extension sync finished at $(date)"
}

# Initial sync for both files
sync_files "$SETTINGS_FILE"
sync_files "$KEYBINDINGS_FILE"

# Initial sync for extensions
sync_extensions

# Watch for changes in both files
fswatch -o "$VSCODE_USER_DIR/$SETTINGS_FILE" "$VSCODE_USER_DIR/$KEYBINDINGS_FILE" | while read -r changed_file; do
  if [[ $changed_file == *"$SETTINGS_FILE" ]]; then
    sync_files "$SETTINGS_FILE"
  elif [[ $changed_file == *"$KEYBINDINGS_FILE" ]]; then
    sync_files "$KEYBINDINGS_FILE"
  fi
done
