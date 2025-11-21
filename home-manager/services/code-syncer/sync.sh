#!/usr/bin/env bash

# --- CONFIGURATION ---

# Base directories
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
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
  "github.codespaces"
  "github.copilot"
  "github.copilot-chat"
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
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd"
  else
    # Fallback paths for Mac apps if not in PATH
    case $cmd in
    "antigravity") echo "/Applications/Antigravity.app/Contents/Resources/app/bin/antigravity" ;;
    "windsurf") echo "/Applications/Windsurf.app/Contents/Resources/app/bin/windsurf" ;;
    "cursor") echo "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" ;;
    *) echo "" ;;
    esac
  fi
}

ensure_dirs() {
  mkdir -p "$ANTIGRAVITY_USER_DIR"
  mkdir -p "$CURSOR_USER_DIR"
  mkdir -p "$WINDSURF_USER_DIR"
}

# Filter out proprietary and AI extensions from the list
clean_extension_list() {
  local input_file="$1"
  local clean_file="$2"

  cp "$input_file" "$clean_file"

  for bad_ext in "${PROPRIETARY_EXTENSIONS[@]}"; do
    # Remove the line containing the bad extension
    sed -i '' "/$bad_ext/d" "$clean_file"
  done

  for ai_ext in "${AI_EXTENSIONS[@]}"; do
    # Remove the line containing the AI extension
    sed -i '' "/$ai_ext/d" "$clean_file"
  done
}

install_extensions() {
  local target_name=$1
  local cli_cmd=$(resolve_cli "$target_name")
  local source_list="$VSCODE_USER_DIR/$EXTENSIONS_FILE"
  local clean_list="/tmp/${target_name}_extensions_clean.list"

  if [ -z "$cli_cmd" ] || [ ! -f "$cli_cmd" ]; then
    echo "⚠️  CLI for $target_name not found. Skipping extension sync."
    return
  fi

  echo "--- Syncing Extensions for $target_name ---"

  # create a clean list without proprietary MS extensions
  clean_extension_list "$source_list" "$clean_list"

  # Log extensions that will be synced
  local extension_count=$(wc -l <"$clean_list" | tr -d ' ')
  echo "📦 Found $extension_count extension(s) to sync:"
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
}

sync_config_file() {
  local filename=$1
  local source="$VSCODE_USER_DIR/$filename"

  if [ -f "$source" ]; then
    echo "Copying $filename to all editors..."
    echo "   📋 Source: $source"
    echo "   📤 Destinations:"
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

# 1. Export VS Code Extensions
if command -v code >/dev/null; then
  code --list-extensions >"$VSCODE_USER_DIR/$EXTENSIONS_FILE"
else
  echo "VS Code CLI not found in path!"
  exit 1
fi

# 2. Sync Config Files
sync_config_file "$SETTINGS_FILE"
sync_config_file "$KEYBINDINGS_FILE"

# 3. Sync Extensions (with filtering)
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
