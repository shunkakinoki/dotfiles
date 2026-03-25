#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'notify-local.sh'
SCRIPT="$PWD/home-manager/modules/local-scripts/notify-local.sh"

Describe 'when message is empty'
It 'exits 0 without sending notification'
When run bash "$SCRIPT" "Title"
The status should be success
End

It 'exits 0 with no arguments'
When run bash "$SCRIPT"
The status should be success
End
End

Describe 'with osascript available'
setup() {
  mock_bin_setup osascript
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'sends notification with title and message'
When run bash -c 'bash '"$SCRIPT"' "My Title" "Hello world"; cat "$MOCK_LOG"'
The status should be success
The output should include 'display notification'
The output should include 'My Title'
The output should include 'Hello world'
End

It 'sends notification with sound'
When run bash -c 'bash '"$SCRIPT"' "Alert" "Something happened" "Basso"; cat "$MOCK_LOG"'
The status should be success
The output should include 'display notification'
The output should include 'sound name "Basso"'
End

It 'sends notification without sound when not specified'
When run bash -c 'bash '"$SCRIPT"' "Alert" "Something happened"; cat "$MOCK_LOG"'
The status should be success
The output should include 'display notification'
The output should not include 'sound name'
End
End

Describe 'with notify-send available (no osascript)'
setup() {
  mock_bin_setup notify-send
  # Hide osascript so notify-send path is taken
  if command -v osascript >/dev/null 2>&1; then
    local bash_dir cat_dir printf_dir
    bash_dir="$(dirname "$(command -v bash)")"
    cat_dir="$(dirname "$(command -v cat)")"
    printf_dir="$(dirname "$(command -v printf)")"
    export PATH="$MOCK_BIN:$bash_dir:$cat_dir:$printf_dir"
  fi
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'uses notify-send'
When run bash -c 'bash '"$SCRIPT"' "Title" "Message"; cat "$MOCK_LOG"'
The status should be success
The output should include 'notify-send'
The output should include 'Title'
The output should include 'Message'
End
End

Describe 'with terminal-notifier available (no osascript or notify-send)'
setup() {
  mock_bin_setup terminal-notifier
  # Hide osascript so terminal-notifier path is taken
  if command -v osascript >/dev/null 2>&1; then
    local bash_dir cat_dir printf_dir
    bash_dir="$(dirname "$(command -v bash)")"
    cat_dir="$(dirname "$(command -v cat)")"
    printf_dir="$(dirname "$(command -v printf)")"
    export PATH="$MOCK_BIN:$bash_dir:$cat_dir:$printf_dir"
  fi
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'uses terminal-notifier'
When run bash -c 'bash '"$SCRIPT"' "Title" "Message"; cat "$MOCK_LOG"'
The status should be success
The output should include 'terminal-notifier'
The output should include 'Title'
The output should include 'Message'
End
End

Describe 'with no notification backend'
setup() {
  MOCK_BIN="$(mktemp -d)"
  MOCK_ORIGINAL_PATH="${PATH:-}"
  local bash_dir
  bash_dir="$(dirname "$(command -v bash)")"
  export PATH="$MOCK_BIN:$bash_dir"
  export MOCK_BIN MOCK_ORIGINAL_PATH
}
cleanup() {
  export PATH="$MOCK_ORIGINAL_PATH"
  rm -rf "$MOCK_BIN"
  unset MOCK_BIN MOCK_ORIGINAL_PATH
}
Before 'setup'
After 'cleanup'

It 'exits 0 silently'
When run bash "$SCRIPT" "Title" "Message"
The status should be success
End
End
End
