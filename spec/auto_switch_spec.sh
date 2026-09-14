#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'auto-switch.sh'
SCRIPT="$PWD/config/claude/hooks/auto-switch.sh"
DEFAULT_NIX="$PWD/config/claude/default.nix"
ACTIVATE_SCRIPT="$PWD/config/claude/activate.sh"
SETTINGS="$PWD/config/claude/settings.json"

Describe 'universal wiring'
It 'enables the CAAM hook on every host'
When run cat "$DEFAULT_NIX"
The output should not include 'inputs.host'
The output should include 'home.file.".claude/hooks/auto-switch.sh"'
End

It 'hydrates StopFailure on every host'
When run bash -c 'temp_home=$(mktemp -d); HOME="$temp_home" bash "'"$ACTIVATE_SCRIPT"'" "'"$SETTINGS"'"; jq -e ".hooks.StopFailure | length > 0" "$temp_home/.claude/settings.json" >/dev/null'
The status should be success
End
End

Describe 'when caam is not installed'
It 'exits 0 silently'
When run bash -c 'echo "{}" | PATH="/usr/bin:/bin" bash '"$SCRIPT"
The status should be success
The output should eq ''
End
End

Describe 'when caam has fewer than 2 accounts'
setup() {
  mock_bin_setup caam
  cat >"$MOCK_BIN/caam" <<'EOF'
#!/usr/bin/env bash
if [[ "$1 $2 $3" == "ls claude --json" ]]; then
  echo '{"profiles":[{"name":"account-a"}]}'
fi
exit 0
EOF
  chmod +x "$MOCK_BIN/caam"
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

Describe 'when caam has 2+ accounts'
setup() {
  MOCK_BIN="$(mktemp -d)"
  MOCK_LOG="$MOCK_BIN/mock.log"
  : >"$MOCK_LOG"
  MOCK_ORIGINAL_PATH="${PATH:-}"
  export MOCK_BIN MOCK_LOG MOCK_ORIGINAL_PATH
  export PATH="$MOCK_BIN:$MOCK_ORIGINAL_PATH"

  cat >"$MOCK_BIN/caam" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$MOCK_LOG"
if [[ "$1 $2 $3" == "ls claude --json" ]]; then
  echo '{"profiles":[{"name":"account-a"},{"name":"account-b"}]}'
elif [[ "$1 $2 $3" == "cooldown set claude" ]]; then
  echo "Cooldown set"
elif [[ "$1 $2 $3" == "activate claude --auto" ]]; then
  echo "Switched to account-b"
fi
exit 0
EOF
  chmod +x "$MOCK_BIN/caam"
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

It 'cools down the active profile and activates the next profile'
When run bash -c 'echo "{\"error\": \"rate_limit\"}" | bash '"$SCRIPT"' 2>/dev/null; cat "$MOCK_LOG"'
The status should be success
The output should include 'cooldown set claude --notes Claude StopFailure rate limit'
The output should include 'activate claude --auto'
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
