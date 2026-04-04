#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'auto-switch.sh'
SCRIPT="$PWD/config/claude/hooks/auto-switch.sh"

Describe 'when cswap is not installed'
It 'exits 0 silently'
When run bash -c 'echo "{}" | PATH="/usr/bin:/bin" bash '"$SCRIPT"
The status should be success
The output should eq ''
End
End

Describe 'when cswap has fewer than 2 accounts'
setup() {
  mock_bin_setup cswap
  cat >"$MOCK_BIN/cswap" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--list" ]]; then
  echo "  1) account-a (active)"
fi
exit 0
EOF
  chmod +x "$MOCK_BIN/cswap"
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'exits 0 silently'
When run bash -c 'echo "{}" | bash '"$SCRIPT"
The status should be success
The output should eq ''
End
End

Describe 'when cswap has 2+ accounts'
setup() {
  MOCK_BIN="$(mktemp -d)"
  MOCK_LOG="$MOCK_BIN/mock.log"
  : >"$MOCK_LOG"
  MOCK_ORIGINAL_PATH="${PATH:-}"
  export MOCK_BIN MOCK_LOG MOCK_ORIGINAL_PATH
  export PATH="$MOCK_BIN:$MOCK_ORIGINAL_PATH"

  cat >"$MOCK_BIN/cswap" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--list" ]]; then
  printf '  1) account-a (active)\n  2) account-b\n'
elif [[ "$1" == "--switch" ]]; then
  echo "Switched to account-b"
fi
exit 0
EOF
  chmod +x "$MOCK_BIN/cswap"
}
cleanup() {
  if [[ -n ${MOCK_ORIGINAL_PATH:-} ]]; then
    export PATH="$MOCK_ORIGINAL_PATH"
  fi
  if [[ -n ${MOCK_BIN:-} ]]; then
    rm -rf "$MOCK_BIN"
  fi
  unset MOCK_BIN MOCK_LOG MOCK_ORIGINAL_PATH
}
Before 'setup'
After 'cleanup'

It 'does nothing for non-rate-limit errors'
When run bash -c 'echo "{\"error\": \"some_other_error\"}" | bash '"$SCRIPT"
The status should be success
The output should eq ''
The error should eq ''
End

It 'switches on rate_limit error'
When run bash -c 'echo "{\"error\": \"rate_limit\"}" | bash '"$SCRIPT"
The status should be success
The error should include 'Auto-switching'
End

It 'switches on 429 in error_details'
When run bash -c 'echo "{\"error_details\": \"status 429\"}" | bash '"$SCRIPT"
The status should be success
The error should include 'Auto-switching'
End

It 'switches on overloaded error'
When run bash -c 'echo "{\"error\": \"overloaded\"}" | bash '"$SCRIPT"
The status should be success
The error should include 'Auto-switching'
End

It 'switches on too_many_requests error'
When run bash -c 'echo "{\"error\": \"too_many_requests\"}" | bash '"$SCRIPT"
The status should be success
The error should include 'Auto-switching'
End

It 'switches on quota error'
When run bash -c 'echo "{\"error\": \"quota_exceeded\"}" | bash '"$SCRIPT"
The status should be success
The error should include 'Auto-switching'
End

It 'switches on capacity error'
When run bash -c 'echo "{\"error\": \"capacity\"}" | bash '"$SCRIPT"
The status should be success
The error should include 'Auto-switching'
End

It 'does nothing for empty JSON'
When run bash -c 'echo "{}" | bash '"$SCRIPT"
The status should be success
The output should eq ''
The error should eq ''
End
End

End
