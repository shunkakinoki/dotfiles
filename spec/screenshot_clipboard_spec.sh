#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'screenshot-clipboard/watch.sh'
SCRIPT="$PWD/home-manager/services/screenshot-clipboard/watch.sh"

It 'is syntactically valid bash'
When run bash -n "$SCRIPT"
The status should be success
End

It 'matches macOS screenshot patterns'
When run grep -F 'Screenshot ' "$SCRIPT"
The status should be success
The output should include 'Screenshot'
End

It 'matches hyprshot pattern'
When run grep -F '_hyprshot.png' "$SCRIPT"
The status should be success
The output should include '_hyprshot.png'
End

It 'matches swappy pattern'
When run grep -F 'swappy-' "$SCRIPT"
The status should be success
The output should include 'swappy-'
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
