#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'code-syncer/sync.sh'
SCRIPT="$PWD/home-manager/services/code-syncer/sync.sh"

Describe 'VS Code CLI detection'
setup() {
  TEMP_HOME=$(mktemp -d)
  # Create empty bin dir to use as PATH, hiding real 'code' command
  EMPTY_BIN=$(mktemp -d)
  OS_TYPE="$(uname -s)"
  if [ "$OS_TYPE" = "Darwin" ]; then
    mkdir -p "$TEMP_HOME/Library/Application Support/Code/User"
    mkdir -p "$TEMP_HOME/Library/Application Support/Cursor/User"
    mkdir -p "$TEMP_HOME/Library/Application Support/Windsurf/User"
    mkdir -p "$TEMP_HOME/Library/Application Support/Antigravity/User"
    mkdir -p "$TEMP_HOME/Library/Application Support/Code - Insiders/User"
  else
    mkdir -p "$TEMP_HOME/.config/Code/User"
    mkdir -p "$TEMP_HOME/.config/Cursor/User"
    mkdir -p "$TEMP_HOME/.config/Windsurf/User"
    mkdir -p "$TEMP_HOME/.config/Antigravity/User"
    mkdir -p "$TEMP_HOME/.config/Code - Insiders/User"
  fi
}

cleanup() {
  rm -rf "$TEMP_HOME" "$EMPTY_BIN"
}

Before 'setup'
After 'cleanup'

It 'exits with error when VS Code CLI not found'
# Use restricted PATH with only essential commands, hiding 'code'
When run bash -c "HOME='$TEMP_HOME' PATH='$EMPTY_BIN:/usr/bin:/bin' bash '$SCRIPT' 2>&1"
The output should include 'VS Code CLI not found'
The status should be failure
End
End

Describe 'extension filtering'
It 'uses code --list-extensions to get extensions'
When run bash -c "grep -E 'code.*--list-extensions' '$SCRIPT'"
The output should include '--list-extensions'
The status should be success
End

It 'isolates VS Code CLI logs from the desktop profile'
When run bash -c "grep -A 6 'list_vscode_extensions()' '$SCRIPT'"
The output should include '--user-data-dir'
The output should include 'code-syncer-vscode-data'
The status should be success
End

It 'quarantines pathological Linux log fan-out without deleting it'
When run bash -c "grep -A 30 'quarantine_oversized_vscode_logs()' '$SCRIPT'"
The output should include '1048576'
The output should include 'code-syncer/quarantine'
The output should include 'mv -f --'
The output should include 'mkdir -p "$log_dir"'
The status should be success
End

It 'filters extensions through clean_extension_list function'
When run bash -c "grep 'clean_extension_list' '$SCRIPT'"
The output should include 'clean_extension_list'
The status should be success
End
End

Describe 'proprietary extension blocklist'
It 'defines proprietary extensions to filter'
When run bash -c "grep -A 20 'PROPRIETARY_EXTENSIONS=' '$SCRIPT' | head -20"
The output should include 'github.copilot'
The output should include 'ms-python.python'
The output should include 'ms-vscode-remote'
End

It 'defines AI extensions to filter'
When run bash -c "grep -A 20 'AI_EXTENSIONS=' '$SCRIPT' | head -20"
The output should include 'github.copilot'
The output should include 'anthropic.claude-code'
End
End

Describe 'config file syncing'
It 'creates the watched VS Code user directory before starting the watcher'
When run bash -c "grep -A 6 'ensure_dirs()' '$SCRIPT'"
The output should include 'mkdir -p "$VSCODE_USER_DIR"'
The status should be success
End

It 'defines sync_config_file function with cp'
When run bash -c "grep -A 15 'sync_config_file()' '$SCRIPT'"
The output should include 'sync_config_file'
The output should include 'cp'
The status should be success
End

It 'syncs settings.json file'
When run bash -c "grep 'SETTINGS_FILE' '$SCRIPT'"
The output should include 'settings.json'
The status should be success
End

It 'syncs keybindings.json file'
When run bash -c "grep 'KEYBINDINGS_FILE' '$SCRIPT'"
The output should include 'keybindings.json'
The status should be success
End
End

Describe 'fswatch integration'
It 'checks for fswatch availability'
When run bash -c "grep 'fswatch' '$SCRIPT'"
The output should include 'fswatch'
End

It 'shows message when fswatch not found'
When run bash -c "grep -A 2 'fswatch not found' '$SCRIPT'"
The output should include 'Auto-sync disabled'
End
End

Describe 'Linux watcher lifecycle'
It 'watches the VS Code user directory so missing files do not end the service'
When run bash -c "grep 'inotifywait -m' '$SCRIPT'"
The output should include '"$VSCODE_USER_DIR"'
The output should include "--format '%f'"
The status should be success
End

It 'does not restart after a clean watcher exit'
When run bash -c "grep 'Restart = ' '$PWD/home-manager/services/code-syncer/default.nix'"
The output should include 'Restart = "on-failure";'
The status should be success
End
End

End
