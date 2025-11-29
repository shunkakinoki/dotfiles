#!/usr/bin/env bash

# --- CONFIGURATION ---

# Base directories
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
VSCODE_INSIDERS_USER_DIR="$HOME/Library/Application Support/Code - Insiders/User"
ANTIGRAVITY_USER_DIR="$HOME/Library/Application Support/Antigravity/User"
CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
WINDSURF_USER_DIR="$HOME/Library/Application Support/Windsurf/User"

# Files
SETTINGS_FILE="settings.json"
KEYBINDINGS_FILE="keybindings.json"
EXTENSIONS_FILE="extensions.list"

# --- BLOCKLIST ---
# These are MS proprietary extensions that typically fail on forks or crash them.
# We filter these out to prevent errors.
PROPRIETARY_EXTENSIONS=(
  "anysphere.pyright"
  "anysphere.cursorpyright"
  "github.codespaces"
  "github.copilot"
  "github.copilot-chat"
  "github.vscode-github-actions"
  "ms-python.debugpy"
  "ms-python.python"
  "ms-python.vscode-pylance"
  "ms-python.vscode-python-envs"
  "ms-vscode-remote.remote-containers"
  "ms-vscode-remote.remote-ssh-edit"
  "ms-vscode-remote.remote-ssh"
  "ms-vscode-remote.remote-wsl"
  "ms-vscode.remote-explorer"
  "ms-vsliveshare.vsliveshare"
)

AI_EXTENSIONS=(
  "anthropic.claude-code"
  "coderabbit.coderabbit-vscode"
  "github.copilot"
  "github.copilot-chat"
  "google.gemini-cli-vscode-ide-companion"
  "google.geminicodeassist"
  "ggml-org.llama-vscode"
  "kilocode.kilo-code"
  "openai.chatgpt"
  "rooveterinaryinc.roo-cline"
  "saoudrizwan.claude-dev"
  "sourcegraph.amp"
  "sst-dev.opencode"
  "sweetpad.sweetpad"
)

# --- HELPER FUNCTIONS ---

# Check if a command exists, if not, try to find it in Applications
resolve_cli() {
  local cmd=$1
  local resolved_path=$(command -v "$cmd" 2>/dev/null)
  if [ -n "$resolved_path" ]; then
    echo "$resolved_path"
  else
    # Fallback paths for Mac apps if not in PATH
    case $cmd in
    "antigravity") echo "/Applications/Antigravity.app/Contents/Resources/app/bin/antigravity" ;;
    "windsurf") echo "/opt/homebrew/bin/windsurf" ;;
    "cursor") echo "/opt/homebrew/bin/cursor" ;;
    "code-insiders") echo "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code" ;;
    *) echo "" ;;
    esac
  fi
}

ensure_dirs() {
  mkdir -p "$ANTIGRAVITY_USER_DIR"
  mkdir -p "$CURSOR_USER_DIR"
  mkdir -p "$WINDSURF_USER_DIR"
  mkdir -p "$VSCODE_INSIDERS_USER_DIR"
}

# Filter out proprietary and AI extensions from the list
# Input can be from stdin (pipe) or a file
clean_extension_list() {
  local input_source="$1" # Can be a file path or "-" for stdin
  local clean_file="$2"

  # Read from stdin if input_source is "-", otherwise from file
  if [ "$input_source" = "-" ]; then
    cat >"$clean_file"
  else
    cp "$input_source" "$clean_file"
  fi

  for bad_ext in "${PROPRIETARY_EXTENSIONS[@]}"; do
    # Remove the line containing the bad extension
    sed -i '' "/$bad_ext/d" "$clean_file"
  done

  for ai_ext in "${AI_EXTENSIONS[@]}"; do
    # Remove the line containing the AI extension
    sed -i '' "/$ai_ext/d" "$clean_file"
  done
}

# Remove unnecessary extensions that shouldn't be synced
remove_unnecessary_extensions() {
  local target_name=$1
  local cli_cmd=$(resolve_cli "$target_name")
  local clean_list="/tmp/${target_name}_extensions_clean.list"
  local installed_list="/tmp/${target_name}_extensions_installed.list"
  local vscode_list="/tmp/vscode_extensions.list"

  if [ -z "$cli_cmd" ] || [ ! -f "$cli_cmd" ]; then
    return
  fi

  # Get list of installed extensions in target editor
  $cli_cmd --list-extensions >"$installed_list" 2>/dev/null
  if [ $? -ne 0 ]; then
    return
  fi

  # Get VS Code extensions directly from CLI
  if ! command -v code >/dev/null 2>&1; then
    echo "⚠️  VS Code CLI not found. Skipping removal check for $target_name."
    return
  fi

  if ! code --list-extensions >"$vscode_list" 2>/dev/null; then
    echo "⚠️  Failed to get VS Code extensions. Skipping removal check for $target_name."
    return
  fi

  if [ ! -s "$vscode_list" ]; then
    # VS Code has no extensions, so nothing to sync/remove
    return
  fi

  # Create clean list of what should be synced
  clean_extension_list "$vscode_list" "$clean_list"

  # Check if clean list has content
  if [ ! -s "$clean_list" ]; then
    # No extensions to sync after filtering
    return
  fi

  # Find extensions to remove (skip PROPRIETARY_EXTENSIONS)
  local to_remove=()
  while IFS= read -r installed_ext; do
    if [ -z "$installed_ext" ]; then
      continue
    fi

    # Skip PROPRIETARY_EXTENSIONS - don't attempt to remove them
    local is_proprietary=false
    for prop_ext in "${PROPRIETARY_EXTENSIONS[@]}"; do
      if [ "$installed_ext" = "$prop_ext" ]; then
        is_proprietary=true
        break
      fi
    done

    if [ "$is_proprietary" = true ]; then
      continue
    fi

    # Check if extension is in VS Code's original list (before filtering)
    # If it's in VS Code, we should keep it (it will be synced)
    local in_vscode=false
    if grep -Fxq "$installed_ext" "$vscode_list" 2>/dev/null; then
      in_vscode=true
    fi

    # If extension is in VS Code, keep it (don't remove)
    if [ "$in_vscode" = true ]; then
      continue
    fi

    # Check if extension is in AI_EXTENSIONS (should be removed)
    local is_ai=false
    for ai_ext in "${AI_EXTENSIONS[@]}"; do
      if [ "$installed_ext" = "$ai_ext" ]; then
        is_ai=true
        break
      fi
    done

    # Remove if it's an AI extension (not in VS Code but installed)
    if [ "$is_ai" = true ]; then
      to_remove+=("$installed_ext")
    fi
  done <"$installed_list"

  # Remove unnecessary extensions
  if [ ${#to_remove[@]} -gt 0 ]; then
    echo "🗑️  Removing ${#to_remove[@]} unnecessary extension(s) from $target_name:"
    for ext in "${to_remove[@]}"; do
      echo "   🗑️  Removing: $ext"
      $cli_cmd --uninstall-extension "$ext" >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        echo "      ✅ Removed: $ext"
      else
        echo "      ⚠️  Failed to remove: $ext"
      fi
    done
    echo ""
  else
    echo "✅ No unnecessary extensions to remove from $target_name"
    echo ""
  fi
}

install_extensions() {
  local target_name=$1
  local cli_cmd=$(resolve_cli "$target_name")
  local clean_list="/tmp/${target_name}_extensions_clean.list"
  local vscode_list="/tmp/vscode_extensions.list"

  if [ -z "$cli_cmd" ] || [ ! -f "$cli_cmd" ]; then
    echo "⚠️  CLI for $target_name not found. Skipping extension sync."
    return
  fi

  echo "--- Syncing Extensions for $target_name ---"

  # Remove unnecessary extensions first
  remove_unnecessary_extensions "$target_name"

  # Get VS Code extensions directly from CLI
  if ! command -v code >/dev/null 2>&1; then
    echo "⚠️  VS Code CLI not found. Skipping extension sync for $target_name."
    return
  fi

  if ! code --list-extensions >"$vscode_list" 2>/dev/null; then
    echo "⚠️  Failed to get VS Code extensions. Skipping extension sync for $target_name."
    return
  fi

  if [ ! -s "$vscode_list" ]; then
    echo "⚠️  VS Code has no extensions. Nothing to sync for $target_name."
    return
  fi

  # create a clean list without proprietary MS extensions
  clean_extension_list "$vscode_list" "$clean_list"

  # Log extensions that will be synced
  local extension_count=$(wc -l <"$clean_list" 2>/dev/null | tr -d ' ' || echo "0")
  extension_count=${extension_count:-0}

  echo "📦 Found $extension_count extension(s) to sync:"

  if [ "$extension_count" -gt 0 ]; then
    while IFS= read -r extension; do
      if [ -n "$extension" ]; then
        echo "   • $extension"
      fi
    done <"$clean_list"
    echo ""

    while IFS= read -r extension; do
      if [ -n "$extension" ]; then
        # Try to install, log failures but don't stop
        $cli_cmd --install-extension "$extension" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
          echo "   ❌ Failed: $extension (Likely missing from Open VSX)"
        else
          # Optional: verify it's actually installed
          echo "   ✅ Synced: $extension"
        fi
      fi
    done <"$clean_list"
  else
    echo "   (No extensions to sync)"
    echo ""
  fi
}

# Special function to sync ALL extensions to VS Code Insiders without any filtering
install_all_extensions_insiders() {
  local target_name="code-insiders"
  local cli_cmd=$(resolve_cli "$target_name")
  local vscode_list="/tmp/vscode_extensions_all.list"

  if [ -z "$cli_cmd" ] || [ ! -f "$cli_cmd" ]; then
    echo "⚠️  CLI for $target_name not found. Skipping extension sync."
    return
  fi

  echo "--- Syncing ALL Extensions for VS Code Insiders (No Filtering) ---"

  # Get VS Code extensions directly from CLI
  if ! command -v code >/dev/null 2>&1; then
    echo "⚠️  VS Code CLI not found. Skipping extension sync for $target_name."
    return
  fi

  if ! code --list-extensions >"$vscode_list" 2>/dev/null; then
    echo "⚠️  Failed to get VS Code extensions. Skipping extension sync for $target_name."
    return
  fi

  if [ ! -s "$vscode_list" ]; then
    echo "⚠️  VS Code has no extensions. Nothing to sync for $target_name."
    return
  fi

  # Log extensions that will be synced
  local extension_count=$(wc -l <"$vscode_list" 2>/dev/null | tr -d ' ' || echo "0")
  extension_count=${extension_count:-0}

  echo "📦 Found $extension_count extension(s) to sync:"

  if [ "$extension_count" -gt 0 ]; then
    while IFS= read -r extension; do
      if [ -n "$extension" ]; then
        echo "   • $extension"
      fi
    done <"$vscode_list"
    echo ""

    while IFS= read -r extension; do
      if [ -n "$extension" ]; then
        # Try to install, log failures but don't stop
        $cli_cmd --install-extension "$extension" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
          echo "   ❌ Failed: $extension"
        else
          # Optional: verify it's actually installed
          echo "   ✅ Synced: $extension"
        fi
      fi
    done <"$vscode_list"
  else
    echo "   (No extensions to sync)"
    echo ""
  fi
}

sync_config_file() {
  local filename=$1
  local source="$VSCODE_USER_DIR/$filename"

  if [ -f "$source" ]; then
    echo "Copying $filename to all editors..."
    echo "   📋 Source: $source"
    echo "   📤 Destinations:"
    echo "      → $VSCODE_INSIDERS_USER_DIR/$filename"
    cp "$source" "$VSCODE_INSIDERS_USER_DIR/$filename"
    echo "      → $ANTIGRAVITY_USER_DIR/$filename"
    cp "$source" "$ANTIGRAVITY_USER_DIR/$filename"
    echo "      → $CURSOR_USER_DIR/$filename"
    cp "$source" "$CURSOR_USER_DIR/$filename"
    echo "      → $WINDSURF_USER_DIR/$filename"
    cp "$source" "$WINDSURF_USER_DIR/$filename"
  fi
}

# --- MAIN EXECUTION ---

echo "Starting Sync..."
ensure_dirs

# 1. Check VS Code CLI availability
if ! command -v code >/dev/null 2>&1; then
  echo "VS Code CLI not found in path!"
  exit 1
fi

# Get VS Code extension count for info
vscode_ext_count=$(code --list-extensions 2>/dev/null | wc -l | tr -d ' ')
if [ "$vscode_ext_count" -gt 0 ]; then
  echo "📋 Found $vscode_ext_count extension(s) in VS Code"
else
  echo "⚠️  VS Code has no extensions installed"
fi

# 2. Sync Config Files
sync_config_file "$SETTINGS_FILE"
sync_config_file "$KEYBINDINGS_FILE"

# 3. Sync Extensions
# Use special all-extension sync for VS Code Insiders (no filtering)
install_all_extensions_insiders
# Keep filtered sync for other editors
install_extensions "antigravity"
install_extensions "cursor"
install_extensions "windsurf"

echo "Initial Sync Complete."

# 4. Watcher (Mac only)
if command -v fswatch >/dev/null; then
  echo "Watching for changes in VS Code settings..."
  fswatch -o "$VSCODE_USER_DIR/$SETTINGS_FILE" "$VSCODE_USER_DIR/$KEYBINDINGS_FILE" | while read num; do
    sync_config_file "$SETTINGS_FILE"
    sync_config_file "$KEYBINDINGS_FILE"
    echo "Updated at $(date)"
  done
else
  echo "fswatch not found. Auto-sync disabled."
fi
