#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'screenshot-clipboard/watch.sh'
SCRIPT="$PWD/home-manager/services/screenshot-clipboard/watch.sh"

It 'is syntactically valid bash'
When run bash -n "$SCRIPT"
The status should be success
End

# Extract only the case-arm logic (between "case" and "esac") so the
# assertions can't be satisfied by matching the documentation comments.
It 'declares screenshot patterns in case-arm logic'
When run awk '/case "\$path" in/,/esac/' "$SCRIPT"
The status should be success
The output should include 'Screenshot '
The output should include 'Screen Shot '
The output should include '_hyprshot.png'
End

It 'anchors patterns to $DESKTOP_DIR to avoid subfolder matches'
When run awk '/case "\$path" in/,/esac/' "$SCRIPT"
The status should be success
The output should include '"$DESKTOP_DIR/'
End

# On Linux inotify, unfiltered fswatch reports reads too; clipboard-copy-image
# reads the screenshot it copies, so without the CloseWrite filter the watcher
# retriggers itself forever and clobbers the clipboard system-wide.
It 'filters fswatch to CloseWrite on Linux to prevent a copy feedback loop'
When run awk '/^if \[ "\$\(uname -s\)" = "Linux" \]/,/^fi/' "$SCRIPT"
The status should be success
The output should include '--event CloseWrite'
End

Describe 'when fswatch is missing'
setup() {
  TEMP_HOME=$(mktemp -d)
  MOCK_BIN="$(mktemp -d)"
  MOCK_ORIGINAL_PATH="${PATH:-}"
  ln -sf "$(command -v bash)" "$MOCK_BIN/bash"
  ln -sf "$(command -v mkdir)" "$MOCK_BIN/mkdir"
  ln -sf "$(command -v command)" "$MOCK_BIN/command" 2>/dev/null || true
  export PATH="$MOCK_BIN"
  export HOME="$TEMP_HOME"
  mkdir -p "$HOME/Desktop"
  export MOCK_BIN MOCK_ORIGINAL_PATH TEMP_HOME
}
cleanup() {
  export PATH="$MOCK_ORIGINAL_PATH"
  rm -rf "$MOCK_BIN" "$TEMP_HOME"
  unset MOCK_BIN MOCK_ORIGINAL_PATH TEMP_HOME
}
Before 'setup'
After 'cleanup'

It 'exits with error'
When run bash "$SCRIPT"
The status should be failure
The stderr should include 'fswatch not found'
End
End

Describe 'when clipboard-copy-image is missing'
setup() {
  TEMP_HOME=$(mktemp -d)
  MOCK_BIN="$(mktemp -d)"
  MOCK_ORIGINAL_PATH="${PATH:-}"
  ln -sf "$(command -v bash)" "$MOCK_BIN/bash"
  ln -sf "$(command -v mkdir)" "$MOCK_BIN/mkdir"
  cat >"$MOCK_BIN/fswatch" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$MOCK_BIN/fswatch"
  export PATH="$MOCK_BIN"
  export HOME="$TEMP_HOME"
  mkdir -p "$HOME/Desktop"
  export MOCK_BIN MOCK_ORIGINAL_PATH TEMP_HOME
}
cleanup() {
  export PATH="$MOCK_ORIGINAL_PATH"
  rm -rf "$MOCK_BIN" "$TEMP_HOME"
  unset MOCK_BIN MOCK_ORIGINAL_PATH TEMP_HOME
}
Before 'setup'
After 'cleanup'

It 'exits with error'
When run bash "$SCRIPT"
The status should be failure
The stderr should include 'clipboard-copy-image not found'
End
End
End
