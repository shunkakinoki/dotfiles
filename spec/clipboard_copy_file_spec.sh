#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'clipboard-copy-file.sh'
SCRIPT="$PWD/home-manager/modules/local-scripts/clipboard-copy-file.sh"

It 'exits with usage error when no args'
When run bash "$SCRIPT"
The status should equal 2
The stderr should include 'usage:'
End

It 'exits with error when file does not exist'
When run bash "$SCRIPT" /nonexistent/file.txt
The status should equal 1
The stderr should include 'file not found'
End

Describe 'when osascript is available'
setup() {
  TEST_DIR=$(mktemp -d)
  TEST_FILE="$TEST_DIR/notes.txt"
  printf 'hi\n' >"$TEST_FILE"
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
  TEST_FILE="$TEST_DIR/notes.txt"
  printf 'hi\n' >"$TEST_FILE"
  mock_bin_setup wl-copy
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

Describe 'when SSH is set with a text file'
setup() {
  TEST_DIR=$(mktemp -d)
  TEST_FILE="$TEST_DIR/notes.txt"
  printf 'hello\n' >"$TEST_FILE"
  MOCK_BIN="$(mktemp -d)"
  MOCK_CACHE="$(mktemp -d)"
  MOCK_ORIGINAL_PATH="${PATH:-}"
  MOCK_ORIGINAL_SSH_CONNECTION="${SSH_CONNECTION:-}"
  MOCK_ORIGINAL_XDG_CACHE_HOME="${XDG_CACHE_HOME:-}"
  local cmd
  for cmd in bash base64 tr printf cat wc tee mkdir chmod dirname; do
    ln -sf "$(command -v "$cmd")" "$MOCK_BIN/$cmd"
  done
  export PATH="$MOCK_BIN"
  export SSH_CONNECTION='1.2.3.4 1234 5.6.7.8 22'
  export XDG_CACHE_HOME="$MOCK_CACHE"
  export MOCK_BIN MOCK_CACHE MOCK_ORIGINAL_PATH MOCK_ORIGINAL_SSH_CONNECTION MOCK_ORIGINAL_XDG_CACHE_HOME
}
cleanup() {
  export PATH="$MOCK_ORIGINAL_PATH"
  if [ -n "$MOCK_ORIGINAL_SSH_CONNECTION" ]; then
    export SSH_CONNECTION="$MOCK_ORIGINAL_SSH_CONNECTION"
  else
    unset SSH_CONNECTION
  fi
  if [ -n "$MOCK_ORIGINAL_XDG_CACHE_HOME" ]; then
    export XDG_CACHE_HOME="$MOCK_ORIGINAL_XDG_CACHE_HOME"
  else
    unset XDG_CACHE_HOME
  fi
  rm -rf "$TEST_DIR" "$MOCK_BIN" "$MOCK_CACHE"
  unset MOCK_BIN MOCK_CACHE MOCK_ORIGINAL_PATH MOCK_ORIGINAL_SSH_CONNECTION MOCK_ORIGINAL_XDG_CACHE_HOME
}
Before 'setup'
After 'cleanup'

It 'sends text files over OSC 52'
When run bash "$SCRIPT" "$TEST_FILE"
The status should be success
The output should start with $'\033]52;c;'
End
End

Describe 'when SSH is set with a binary file'
setup() {
  TEST_DIR=$(mktemp -d)
  TEST_FILE="$TEST_DIR/blob.bin"
  printf 'a\0b' >"$TEST_FILE"
  MOCK_BIN="$(mktemp -d)"
  MOCK_ORIGINAL_PATH="${PATH:-}"
  MOCK_ORIGINAL_SSH_CONNECTION="${SSH_CONNECTION:-}"
  local cmd
  for cmd in bash base64 tr printf wc; do
    ln -sf "$(command -v "$cmd")" "$MOCK_BIN/$cmd"
  done
  export PATH="$MOCK_BIN"
  export SSH_CONNECTION='1.2.3.4 1234 5.6.7.8 22'
  export MOCK_BIN MOCK_ORIGINAL_PATH MOCK_ORIGINAL_SSH_CONNECTION
}
cleanup() {
  export PATH="$MOCK_ORIGINAL_PATH"
  if [ -n "$MOCK_ORIGINAL_SSH_CONNECTION" ]; then
    export SSH_CONNECTION="$MOCK_ORIGINAL_SSH_CONNECTION"
  else
    unset SSH_CONNECTION
  fi
  rm -rf "$TEST_DIR" "$MOCK_BIN"
  unset MOCK_BIN MOCK_ORIGINAL_PATH MOCK_ORIGINAL_SSH_CONNECTION
}
Before 'setup'
After 'cleanup'

It 'emits OSC 5522 for binary files'
When run bash "$SCRIPT" "$TEST_FILE"
The status should be success
The output should start with $'\033]5522;type=write'
End
End
End
