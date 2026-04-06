#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'clipboard-paste.sh'
SCRIPT="$PWD/home-manager/modules/local-scripts/clipboard-paste.sh"

Describe 'when pbpaste is available'
setup() {
  MOCK_BIN="$(mktemp -d)"
  MOCK_ORIGINAL_PATH="${PATH:-}"
  export MOCK_BIN MOCK_ORIGINAL_PATH
  export PATH="$MOCK_BIN:$MOCK_ORIGINAL_PATH"
  cat >"$MOCK_BIN/pbpaste" <<'EOF'
#!/usr/bin/env bash
printf 'hello'
EOF
  chmod +x "$MOCK_BIN/pbpaste"
}
cleanup() {
  export PATH="$MOCK_ORIGINAL_PATH"
  rm -rf "$MOCK_BIN"
  unset MOCK_BIN MOCK_ORIGINAL_PATH
}
Before 'setup'
After 'cleanup'

It 'uses pbpaste'
When run bash "$SCRIPT"
The status should be success
The output should eq 'hello'
End
End

Describe 'when wl-paste is available on Wayland'
setup() {
  MOCK_BIN="$(mktemp -d)"
  MOCK_ORIGINAL_PATH="${PATH:-}"
  export MOCK_BIN MOCK_ORIGINAL_PATH
  export WAYLAND_DISPLAY=wayland-0
  cat >"$MOCK_BIN/wl-paste" <<'EOF'
#!/usr/bin/env bash
printf 'hello'
EOF
  chmod +x "$MOCK_BIN/wl-paste"
  local bash_dir
  bash_dir="$(dirname "$(readlink -f "$(command -v bash)")")"
  export PATH="$MOCK_BIN:$bash_dir"
}
cleanup() {
  export PATH="$MOCK_ORIGINAL_PATH"
  rm -rf "$MOCK_BIN"
  unset MOCK_BIN MOCK_ORIGINAL_PATH WAYLAND_DISPLAY
}
Before 'setup'
After 'cleanup'

It 'uses wl-paste'
When run bash "$SCRIPT"
The status should be success
The output should eq 'hello'
End
End

Describe 'when xclip is available'
setup() {
  MOCK_BIN="$(mktemp -d)"
  MOCK_ORIGINAL_PATH="${PATH:-}"
  export MOCK_BIN MOCK_ORIGINAL_PATH
  unset WAYLAND_DISPLAY
  cat >"$MOCK_BIN/xclip" <<'EOF'
#!/usr/bin/env bash
printf 'hello'
EOF
  chmod +x "$MOCK_BIN/xclip"
  local bash_dir
  bash_dir="$(dirname "$(readlink -f "$(command -v bash)")")"
  export PATH="$MOCK_BIN:$bash_dir"
}
cleanup() {
  export PATH="$MOCK_ORIGINAL_PATH"
  rm -rf "$MOCK_BIN"
  unset MOCK_BIN MOCK_ORIGINAL_PATH
}
Before 'setup'
After 'cleanup'

It 'uses xclip'
When run bash "$SCRIPT"
The status should be success
The output should eq 'hello'
End
End

Describe 'when xsel is available'
setup() {
  MOCK_BIN="$(mktemp -d)"
  MOCK_ORIGINAL_PATH="${PATH:-}"
  MOCK_ORIGINAL_WAYLAND="${WAYLAND_DISPLAY:-}"
  # create mocks before restricting PATH
  cat >"$MOCK_BIN/xsel" <<'EOF'
#!/usr/bin/env bash
printf 'hello'
EOF
  chmod +x "$MOCK_BIN/xsel"
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

It 'uses xsel'
When run bash "$SCRIPT"
The status should be success
The output should eq 'hello'
End
End

Describe 'when no clipboard backend is available'
setup() {
  MOCK_BIN="$(mktemp -d)"
  MOCK_ORIGINAL_PATH="${PATH:-}"
  MOCK_ORIGINAL_WAYLAND="${WAYLAND_DISPLAY:-}"
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
When run bash "$SCRIPT"
The status should be failure
The stderr should include 'No clipboard backend available'
End
End
End
