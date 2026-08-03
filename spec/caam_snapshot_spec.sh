#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016,SC2089,SC2090

Describe 'Claude CAAM session snapshot hook'
SCRIPT="$PWD/config/claude/hooks/caam-snapshot.sh"
DEFAULT_NIX="$PWD/config/claude/default.nix"
SETTINGS="$PWD/config/claude/settings.json"

setup() {
  MOCK_BIN=$(mktemp -d)
  MOCK_LOG="$MOCK_BIN/mock.log"
  ORIGINAL_PATH=${PATH:-}
  export MOCK_BIN MOCK_LOG ORIGINAL_PATH
  export PATH="$MOCK_BIN:$ORIGINAL_PATH"
  : >"$MOCK_LOG"

  cat >"$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
if [[ -n ${CLAUDE_AUTH_STATUS:-} ]]; then
  printf '%s\n' "$CLAUDE_AUTH_STATUS"
else
  printf '%s\n' '{"loggedIn":false}'
fi
EOF
  cat >"$MOCK_BIN/caam" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$MOCK_LOG"
if [[ "$1 $2 $3" == "ls claude --json" ]]; then
  if [[ -n ${CAAM_PROFILES:-} ]]; then
    printf '%s\n' "$CAAM_PROFILES"
  else
    printf '%s\n' '{"profiles":[]}'
  fi
fi
if [[ "$1 $2" == "backup claude" ]]; then
  exit "${CAAM_BACKUP_EXIT_CODE:-0}"
fi
exit 0
EOF
  chmod +x "$MOCK_BIN/claude" "$MOCK_BIN/caam"
}

cleanup() {
  export PATH="$ORIGINAL_PATH"
  rm -rf "$MOCK_BIN"
  unset MOCK_BIN MOCK_LOG ORIGINAL_PATH CLAUDE_AUTH_STATUS CAAM_PROFILES CAAM_BACKUP_EXIT_CODE
}

Before 'setup'
After 'cleanup'

It 'backs up the authenticated existing email profile'
CLAUDE_AUTH_STATUS='{"loggedIn":true,"email":"work@example.com"}'
CAAM_PROFILES='{"profiles":[{"name":"work@example.com"}]}'
export CLAUDE_AUTH_STATUS CAAM_PROFILES
When run bash -c 'echo "{\"hook_event_name\":\"SessionEnd\"}" | bash "$1"; cat "$2"' _ "$SCRIPT" "$MOCK_LOG"
The status should be success
The output should include 'ls claude --json'
The output should include 'backup claude work@example.com'
End

It 'does not create a profile for an unauthenticated session'
CLAUDE_AUTH_STATUS='{"loggedIn":false,"email":"work@example.com"}'
export CLAUDE_AUTH_STATUS
When run bash -c 'echo "{}" | bash "$1"; cat "$2"' _ "$SCRIPT" "$MOCK_LOG"
The status should be success
The output should eq ''
End

It 'does not create an unknown profile'
CLAUDE_AUTH_STATUS='{"loggedIn":true,"email":"other@example.com"}'
CAAM_PROFILES='{"profiles":[{"name":"work@example.com"}]}'
export CLAUDE_AUTH_STATUS CAAM_PROFILES
When run bash -c 'echo "{}" | bash "$1"; cat "$2"' _ "$SCRIPT" "$MOCK_LOG"
The status should be success
The output should include 'ls claude --json'
The output should not include 'backup claude'
End

It 'keeps CAAM backup failures non-blocking'
CLAUDE_AUTH_STATUS='{"loggedIn":true,"email":"work@example.com"}'
CAAM_PROFILES='{"profiles":[{"name":"work@example.com"}]}'
CAAM_BACKUP_EXIT_CODE=1
export CLAUDE_AUTH_STATUS CAAM_PROFILES CAAM_BACKUP_EXIT_CODE
When run bash -c 'echo "{}" | bash "$1"; cat "$2"' _ "$SCRIPT" "$MOCK_LOG"
The status should be success
The output should include 'backup claude work@example.com'
End

It 'is deployed by Home Manager'
When run bash -c 'grep -F '\''home.file.".claude/hooks/caam-snapshot.sh"'\'' "$1" >/dev/null' _ "$DEFAULT_NIX"
The status should be success
End

It 'is registered as a synchronous SessionEnd hook'
When run bash -c 'jq -e '\''.hooks.SessionEnd[]?.hooks[]? | select(.command == "$HOME/.claude/hooks/caam-snapshot.sh" and .async == false)'\'' "$1" >/dev/null' _ "$SETTINGS"
The status should be success
End

End
