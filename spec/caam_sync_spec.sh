#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'Galactica Claude CAAM sync'
SCRIPT="$PWD/config/caam/sync-claude-remotes.sh"
MAKEFILE="$PWD/Makefile"

setup() {
  MOCK_BIN=$(mktemp -d)
  TEST_HOME=$(mktemp -d)
  MOCK_LOG="$MOCK_BIN/mock.log"
  ORIGINAL_PATH=${PATH:-}
  export MOCK_BIN MOCK_LOG TEST_HOME ORIGINAL_PATH
  export PATH="$MOCK_BIN:$ORIGINAL_PATH"
  : >"$MOCK_LOG"

  cat >"$MOCK_BIN/caam" <<'EOF'
#!/usr/bin/env bash
printf 'caam %s\n' "$*" >>"$MOCK_LOG"
if [[ "$1 $2 $3" == "ls claude --json" ]]; then
  printf '%s\n' '{"profiles":[{"name":"first@example.com"},{"name":"second@example.com"}]}'
elif [[ $1 == export ]]; then
  while (($#)); do
    if [[ $1 == --output ]]; then
      printf archive >"$2"
      break
    fi
    shift
  done
fi
EOF
  cat >"$MOCK_BIN/ssh" <<'EOF'
#!/usr/bin/env bash
printf 'ssh %s\n' "$*" >>"$MOCK_LOG"
cat >/dev/null
EOF
  cat >"$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
if [[ ${MOCK_CLAUDE_LOGGED_IN:-1} == 1 ]]; then
  jq -n --arg email "${CAAM_SYNC_ACTIVE_PROFILE:-second@example.com}" \
    '{loggedIn: true, email: $email}'
else
  printf '%s\n' '{"loggedIn":false,"authMethod":"none"}'
fi
EOF
  chmod +x "$MOCK_BIN/caam" "$MOCK_BIN/claude" "$MOCK_BIN/ssh"

  cat >"$MOCK_BIN/failing-make" <<'EOF'
#!/usr/bin/env bash
exit 17
EOF
  chmod +x "$MOCK_BIN/failing-make"
}

cleanup() {
  export PATH="$ORIGINAL_PATH"
  rm -rf "$MOCK_BIN" "$TEST_HOME"
  unset MOCK_BIN MOCK_LOG TEST_HOME ORIGINAL_PATH
  unset CAAM_SYNC_SOURCE_HOST CAAM_SYNC_TARGETS CAAM_SYNC_PROFILES
  unset CAAM_SYNC_ACTIVE_PROFILE CAAM_SYNC_VERIFY
  unset MOCK_CLAUDE_LOGGED_IN
}

Before 'setup'
After 'cleanup'

It 'refuses to export credentials away from Galactica'
CAAM_SYNC_SOURCE_HOST=matic
export CAAM_SYNC_SOURCE_HOST
When run bash "$SCRIPT"
The status should be failure
The stderr should include 'run this on Galactica'
End

It 'refuses to overwrite remotes from a provider-invalid source login'
CAAM_SYNC_SOURCE_HOST=galactica
CAAM_SYNC_ACTIVE_PROFILE='second@example.com'
MOCK_CLAUDE_LOGGED_IN=0
export CAAM_SYNC_SOURCE_HOST CAAM_SYNC_ACTIVE_PROFILE MOCK_CLAUDE_LOGGED_IN
When run bash "$SCRIPT"
The status should be failure
The stderr should include 'not logged in to the preferred Claude account'
The stderr should include 'claude auth login --email second@example.com'
End

It 'imports each profile and activates the preferred account on each target'
CAAM_SYNC_SOURCE_HOST=galactica
CAAM_SYNC_TARGETS='matic kyber'
CAAM_SYNC_PROFILES='first@example.com second@example.com'
CAAM_SYNC_ACTIVE_PROFILE='second@example.com'
export CAAM_SYNC_SOURCE_HOST CAAM_SYNC_TARGETS CAAM_SYNC_PROFILES CAAM_SYNC_ACTIVE_PROFILE
When run bash -c 'bash "$1" 2>/dev/null; cat "$2"' _ "$SCRIPT" "$MOCK_LOG"
The status should be success
The output should include 'caam backup claude second@example.com'
The output should include 'caam export claude/first@example.com'
The output should include 'caam export claude/second@example.com'
The output should include 'ssh -o BatchMode=yes matic caam import - --force >/dev/null'
The output should include 'ssh -o BatchMode=yes kyber caam import - --force >/dev/null'
The output should include "ssh -o BatchMode=yes matic caam activate claude 'second@example.com' --force >/dev/null"
The output should include "ssh -o BatchMode=yes kyber caam activate claude 'second@example.com' --force >/dev/null"
End

It 'offers explicit provider verification through the managed launcher'
CAAM_SYNC_SOURCE_HOST=galactica
CAAM_SYNC_TARGETS=matic
CAAM_SYNC_PROFILES='first@example.com second@example.com'
CAAM_SYNC_ACTIVE_PROFILE='second@example.com'
CAAM_SYNC_VERIFY=1
export CAAM_SYNC_SOURCE_HOST CAAM_SYNC_TARGETS CAAM_SYNC_PROFILES CAAM_SYNC_ACTIVE_PROFILE CAAM_SYNC_VERIFY
When run bash -c 'bash "$1" 2>/dev/null; cat "$2"' _ "$SCRIPT" "$MOCK_LOG"
The status should be success
The output should include '_clxe_function "Reply exactly OK"'
End

It 'rehydrates Nix-owned Claude settings after dotagents sync'
When run grep -A5 '^dotagents-sync:' "$MAKEFILE"
The output should include 'config/claude/activate.sh'
The output should include 'exit $$status'
End

It 'rehydrates Claude settings even when dotagents sync fails'
When run bash -c 'set +e; HOME="$1" make -f "$2" dotagents-sync MAKE="$3" >/dev/null 2>&1; result=$?; test "$result" -ne 0 && printf "sync_failed=true\n"; jq -r '\''[.hooks.SessionEnd[]?.hooks[]? | select(.command == "caam-claude-snapshot")] | length'\'' "$1/.claude/settings.json"' _ "$TEST_HOME" "$MAKEFILE" "$MOCK_BIN/failing-make"
The status should be success
The output should include 'sync_failed=true'
The output should include '1'
End

It 'exposes a make target for explicit credential sync'
When run grep -A2 '^caam-sync-claude:' "$MAKEFILE"
The output should include 'config/caam/sync-claude-remotes.sh'
End

End
