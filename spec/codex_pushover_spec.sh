#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'codex hooks/pushover.sh'
SCRIPT="$PWD/config/codex/hooks/pushover.sh"

Describe 'without pushover-notify'
setup() {
  MOCK_BIN="$(mktemp -d)"
  MOCK_ORIGINAL_PATH="${PATH:-}"
  # Build a PATH with basic utilities but without pushover-notify
  local bash_dir cat_dir jq_dir sed_dir hostname_dir head_dir grep_dir
  bash_dir="$(dirname "$(command -v bash)")"
  cat_dir="$(dirname "$(command -v cat)")"
  jq_dir="$(dirname "$(command -v jq 2>/dev/null || echo /nonexistent)")"
  sed_dir="$(dirname "$(command -v sed)")"
  hostname_dir="$(dirname "$(command -v hostname 2>/dev/null || echo /nonexistent)")"
  head_dir="$(dirname "$(command -v head)")"
  grep_dir="$(dirname "$(command -v grep)")"
  export PATH="$MOCK_BIN:$bash_dir:$cat_dir:$jq_dir:$sed_dir:$hostname_dir:$head_dir:$grep_dir"
  export MOCK_BIN MOCK_ORIGINAL_PATH
}
cleanup() {
  export PATH="$MOCK_ORIGINAL_PATH"
  rm -rf "$MOCK_BIN"
  unset MOCK_BIN MOCK_ORIGINAL_PATH
}
Before 'setup'
After 'cleanup'

It 'exits silently when pushover-notify is not available'
Data '{"hook_event_name": "Stop", "cwd": "/tmp"}'
When run bash "$SCRIPT"
The status should be success
End
End

Describe 'with pushover-notify'
setup() {
  mock_bin_setup pushover-notify scutil
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'sends notification on Stop'
Data '{"hook_event_name": "Stop", "last_assistant_message": "Done editing", "cwd": "/tmp"}'
When run bash -c "bash '$SCRIPT'; cat \"\$MOCK_LOG\""
The status should be success
The output should include 'pushover-notify'
The output should include 'Codex'
End

It 'sends notification on SessionStart'
Data '{"hook_event_name": "SessionStart", "source": "startup", "cwd": "/tmp"}'
When run bash -c "bash '$SCRIPT'; cat \"\$MOCK_LOG\""
The status should be success
The output should include 'pushover-notify'
The output should include 'Session started'
End
End
End
