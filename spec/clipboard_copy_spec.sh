#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'clipboard-copy.sh'
SCRIPT="$PWD/home-manager/modules/local-scripts/clipboard-copy.sh"

Describe 'when pbcopy is available'
setup() {
  mock_bin_setup pbcopy
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'uses pbcopy'
When run bash "$SCRIPT" </dev/null
The status should be success
End
End

Describe 'when wl-copy is available on Wayland'
setup() {
  mock_bin_setup wl-copy
  export WAYLAND_DISPLAY=wayland-0
}
cleanup() {
  mock_bin_cleanup
  unset WAYLAND_DISPLAY
}
Before 'setup'
After 'cleanup'

It 'uses wl-copy'
When run bash "$SCRIPT" </dev/null
The status should be success
End
End

Describe 'when xclip is available'
setup() {
  mock_bin_setup xclip
  # Restrict PATH so higher-priority backends (real xclip, pbcopy, etc.) are hidden
  local bash_dir
  bash_dir="$(dirname "$(readlink -f "$(command -v bash)")")"
  export PATH="$MOCK_BIN:$bash_dir"
  unset WAYLAND_DISPLAY
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'uses xclip'
When run bash "$SCRIPT" </dev/null
The status should be success
End
End

Describe 'when xsel is available'
setup() {
  mock_bin_setup xsel
  # Restrict PATH so higher-priority backends (real xclip, pbcopy, etc.) are hidden
  local bash_dir
  bash_dir="$(dirname "$(readlink -f "$(command -v bash)")")"
  export PATH="$MOCK_BIN:$bash_dir"
  unset WAYLAND_DISPLAY
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'uses xsel'
When run bash "$SCRIPT" </dev/null
The status should be success
End
End

Describe 'when no clipboard backend is available'
setup() {
  MOCK_BIN="$(mktemp -d)"
  MOCK_ORIGINAL_PATH="${PATH:-}"
  MOCK_ORIGINAL_WAYLAND="${WAYLAND_DISPLAY:-}"
  # Keep bash on PATH but nothing else
  # Use readlink -f to resolve to nix store path (avoids NixOS profile bin with all packages)
  local bash_dir
  bash_dir="$(dirname "$(readlink -f "$(command -v bash)")")"
  export PATH="$MOCK_BIN:$bash_dir"
  unset WAYLAND_DISPLAY
  export MOCK_BIN MOCK_ORIGINAL_PATH MOCK_ORIGINAL_WAYLAND
}
cleanup() {
  export PATH="$MOCK_ORIGINAL_PATH"
  if [ -n "$MOCK_ORIGINAL_WAYLAND" ]; then
    export WAYLAND_DISPLAY="$MOCK_ORIGINAL_WAYLAND"
  fi
  rm -rf "$MOCK_BIN"
  unset MOCK_BIN MOCK_ORIGINAL_PATH MOCK_ORIGINAL_WAYLAND
}
Before 'setup'
After 'cleanup'

It 'exits with error'
When run bash "$SCRIPT" </dev/null
The status should be failure
The stderr should include 'No clipboard backend available'
End
End
End
