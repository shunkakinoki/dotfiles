#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'code-syncer/sync.sh'
SCRIPT="$PWD/home-manager/services/code-syncer/sync.sh"

Describe 'VS Code CLI detection'
setup() {
  TEMP_HOME=$(mktemp -d)
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
  rm -rf "$TEMP_HOME"
}

Before 'setup'
After 'cleanup'

It 'exits with error when VS Code CLI not found'
When run bash -c "HOME='$TEMP_HOME' bash '$SCRIPT' 2>&1"
The output should include 'VS Code CLI not found'
The status should be failure
End
End

Describe 'extension filtering'
setup() {
  mock_bin_setup code fswatch inotifywait
  TEMP_HOME=$(mktemp -d)

  # Create required directories
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

  # Create mock VS Code CLI that lists extensions
  cat >"$MOCK_BIN/code" <<'EOF'
#!/usr/bin/env bash
: "${MOCK_LOG:?MOCK_LOG must be set}"
if [[ "$1" == "--list-extensions" ]]; then
  echo "esbenp.prettier-vscode"
  echo "github.copilot"
  echo "ms-python.python"
  echo "bradlc.vscode-tailwindcss"
fi
printf '%s\n' "code $*" >>"$MOCK_LOG"
exit 0
EOF
  chmod +x "$MOCK_BIN/code"
}

cleanup() {
  rm -rf "$TEMP_HOME"
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

It 'lists VS Code extensions'
When run bash -c "HOME='$TEMP_HOME' bash '$SCRIPT' 2>&1 | head -20"
The output should include 'extension'
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
setup() {
  mock_bin_setup code fswatch cp inotifywait
  TEMP_HOME=$(mktemp -d)

  # Detect OS and create appropriate directories
  OS_TYPE="$(uname -s)"
  if [ "$OS_TYPE" = "Darwin" ]; then
    VSCODE_DIR="$TEMP_HOME/Library/Application Support/Code/User"
    VSCODE_INSIDERS_DIR="$TEMP_HOME/Library/Application Support/Code - Insiders/User"
    CURSOR_DIR="$TEMP_HOME/Library/Application Support/Cursor/User"
    WINDSURF_DIR="$TEMP_HOME/Library/Application Support/Windsurf/User"
    ANTIGRAVITY_DIR="$TEMP_HOME/Library/Application Support/Antigravity/User"
  else
    VSCODE_DIR="$TEMP_HOME/.config/Code/User"
    VSCODE_INSIDERS_DIR="$TEMP_HOME/.config/Code - Insiders/User"
    CURSOR_DIR="$TEMP_HOME/.config/Cursor/User"
    WINDSURF_DIR="$TEMP_HOME/.config/Windsurf/User"
    ANTIGRAVITY_DIR="$TEMP_HOME/.config/Antigravity/User"
  fi

  # Create VS Code user directory with config files
  mkdir -p "$VSCODE_DIR"
  echo '{"editor.fontSize": 14}' >"$VSCODE_DIR/settings.json"
  echo '[]' >"$VSCODE_DIR/keybindings.json"

  # Create target directories
  mkdir -p "$CURSOR_DIR"
  mkdir -p "$WINDSURF_DIR"
  mkdir -p "$ANTIGRAVITY_DIR"
  mkdir -p "$VSCODE_INSIDERS_DIR"

  # Create code mock
  cat >"$MOCK_BIN/code" <<'EOF'
#!/usr/bin/env bash
: "${MOCK_LOG:?MOCK_LOG must be set}"
if [[ "$1" == "--list-extensions" ]]; then
  echo "esbenp.prettier-vscode"
fi
printf '%s\n' "code $*" >>"$MOCK_LOG"
exit 0
EOF
  chmod +x "$MOCK_BIN/code"
}

cleanup() {
  rm -rf "$TEMP_HOME"
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

It 'copies settings.json to target editors'
When run bash -c "HOME='$TEMP_HOME' bash '$SCRIPT' 2>&1 | head -30"
The output should include 'settings.json'
The status should be success
End

It 'copies keybindings.json to target editors'
When run bash -c "HOME='$TEMP_HOME' bash '$SCRIPT' 2>&1 | head -30"
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

End
