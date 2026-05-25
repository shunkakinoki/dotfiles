#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'clipboard-copy-image.sh'
SCRIPT="$PWD/home-manager/modules/local-scripts/clipboard-copy-image.sh"

It 'exits with usage error when no args'
When run bash "$SCRIPT"
The status should equal 2
The stderr should include 'usage:'
End

It 'exits with error when file does not exist'
When run bash "$SCRIPT" /nonexistent/file.png
The status should equal 1
The stderr should include 'file not found'
End

Describe 'when osascript is available'
setup() {
  TEST_DIR=$(mktemp -d)
  TEST_FILE="$TEST_DIR/test.png"
  : >"$TEST_FILE"
  mock_bin_setup osascript
}
cleanup() {
  rm -rf "$TEST_DIR"
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'uses osascript'
When run bash "$SCRIPT" "$TEST_FILE"
The status should be success
End
End

Describe 'when wl-copy is available on Wayland'
setup() {
  TEST_DIR=$(mktemp -d)
  TEST_FILE="$TEST_DIR/test.png"
  : >"$TEST_FILE"
  mock_bin_setup wl-copy
  # Restrict PATH so osascript (higher priority) is hidden
  local bash_dir
  bash_dir="$(resolve_cmd_dir bash)"
  export PATH="$MOCK_BIN:$bash_dir"
  export WAYLAND_DISPLAY=wayland-0
}
cleanup() {
  mock_bin_cleanup
  rm -rf "$TEST_DIR"
  unset WAYLAND_DISPLAY
}
Before 'setup'
After 'cleanup'

It 'uses wl-copy'
When run bash "$SCRIPT" "$TEST_FILE"
The status should be success
End
End

Describe 'when xclip is available'
setup() {
  TEST_DIR=$(mktemp -d)
  TEST_FILE="$TEST_DIR/test.png"
  : >"$TEST_FILE"
  mock_bin_setup xclip
  local bash_dir
  bash_dir="$(resolve_cmd_dir bash)"
  export PATH="$MOCK_BIN:$bash_dir"
  unset WAYLAND_DISPLAY
}
cleanup() {
  mock_bin_cleanup
  rm -rf "$TEST_DIR"
}
Before 'setup'
After 'cleanup'

It 'uses xclip'
When run bash "$SCRIPT" "$TEST_FILE"
The status should be success
End
End

Describe 'when no clipboard backend is available'
setup() {
  TEST_DIR=$(mktemp -d)
  TEST_FILE="$TEST_DIR/test.png"
  : >"$TEST_FILE"
  MOCK_BIN="$(mktemp -d)"
  MOCK_ORIGINAL_PATH="${PATH:-}"
  MOCK_ORIGINAL_WAYLAND="${WAYLAND_DISPLAY:-}"
  ln -sf "$(command -v bash)" "$MOCK_BIN/bash"
  ln -sf "$(command -v printf)" "$MOCK_BIN/printf" 2>/dev/null || true
  export PATH="$MOCK_BIN"
  unset WAYLAND_DISPLAY
  export MOCK_BIN MOCK_ORIGINAL_PATH MOCK_ORIGINAL_WAYLAND
}
cleanup() {
  export PATH="$MOCK_ORIGINAL_PATH"
  if [ -n "$MOCK_ORIGINAL_WAYLAND" ]; then
    export WAYLAND_DISPLAY="$MOCK_ORIGINAL_WAYLAND"
  fi
  rm -rf "$TEST_DIR" "$MOCK_BIN"
  unset MOCK_BIN MOCK_ORIGINAL_PATH MOCK_ORIGINAL_WAYLAND
}
Before 'setup'
After 'cleanup'

It 'exits with error'
When run bash "$SCRIPT" "$TEST_FILE"
The status should be failure
The stderr should include 'No image clipboard backend available'
End
End
End
