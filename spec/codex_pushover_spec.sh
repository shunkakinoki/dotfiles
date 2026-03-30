#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'codex hooks/pushover.sh'
SCRIPT="$PWD/config/codex/hooks/pushover.sh"

Describe 'without pushover-notify'
  It 'exits silently when pushover-notify is not available'
  Data '{"hook_event_name": "Stop", "cwd": "/tmp"}'
  When run bash -c "PATH=/usr/bin:/bin bash '$SCRIPT'"
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
