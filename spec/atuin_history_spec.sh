#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'atuin-history.sh'
HOOK_SCRIPT="$PWD/config/claude/atuin-history.sh"
CLAUDE_DEFAULT="$PWD/config/claude/default.nix"
CLAUDE_SETTINGS="$PWD/config/claude/settings.json"
BASH_CONFIG="$PWD/home-manager/programs/bash/default.nix"
ZSH_CONFIG="$PWD/home-manager/programs/zsh/default.nix"

run_hook() {
  printf '%s\n' "$1" | PATH="$MOCK_BIN:$PATH" HOME=/nonexistent bash "$HOOK_SCRIPT"
}

run_hook_and_log() {
  run_hook "$1"
  cat "$MOCK_LOG"
}

Describe 'hook behavior'
setup() {
  mock_bin_setup

  cat >"$MOCK_BIN/atuin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${MOCK_LOG:?MOCK_LOG must be set}"
subcommand="$1"
action="$2"
shift 2
printf 'cwd=%s subcommand=%s action=%s author=%s intent=%s args=%s\n' \
  "$PWD" \
  "$subcommand" \
  "$action" \
  "${ATUIN_HISTORY_AUTHOR:-}" \
  "${ATUIN_HISTORY_INTENT:-}" \
  "$*" >>"$MOCK_LOG"
if [ "$subcommand" = "history" ] && [ "$action" = "start" ]; then
  printf 'mock-history-id\n'
fi
EOF
  chmod +x "$MOCK_BIN/atuin"

  TEMP_CWD=$(mktemp -d)
}

cleanup() {
  rm -rf "$TEMP_CWD"
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

It 'records completed Bash commands with object tool_result'
When run run_hook_and_log "{\"cwd\":\"$TEMP_CWD\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo hook-test\",\"description\":\"Testing hook\"},\"tool_result\":{\"exit_code\":0,\"duration_ms\":12}}"
The status should be success
The output should include "cwd=$TEMP_CWD subcommand=history action=start author=claude intent=Testing hook args=-- echo hook-test"
The output should include "cwd=$TEMP_CWD subcommand=history action=end author=claude intent=Testing hook args=--exit 0 --duration 12 mock-history-id"
End

It 'records completed Bash commands with string tool_result'
When run run_hook_and_log "{\"cwd\":\"$TEMP_CWD\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo hello\",\"description\":\"Say hello\"},\"tool_result\":\"hello\"}"
The status should be success
The output should include "cwd=$TEMP_CWD subcommand=history action=start author=claude intent=Say hello args=-- echo hello"
The output should include "cwd=$TEMP_CWD subcommand=history action=end author=claude intent=Say hello args=--exit 0 --duration 0 mock-history-id"
End

It 'skips background Bash commands'
When run run_hook_and_log "{\"cwd\":\"$TEMP_CWD\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sleep 1\",\"run_in_background\":true},\"tool_result\":\"running\"}"
The status should be success
The output should eq ''
End

It 'skips non-Bash tool events'
When run run_hook_and_log '{"cwd":"/tmp","tool_name":"Read","tool_input":{"path":"README.md"},"tool_result":"file contents"}'
The status should be success
The output should eq ''
End
End

Describe 'hook wiring'
It 'registers the hook file in Claude Home Manager config'
When run bash -c "grep -F 'home.file.\".claude/hooks/atuin-history.sh\"' '$CLAUDE_DEFAULT'"
The status should be success
The output should include '.claude/hooks/atuin-history.sh'
End

It 'registers the PostToolUse Bash hook in Claude settings'
When run bash -c "grep -F '\"command\": \"\$HOME/.claude/hooks/atuin-history.sh\"' '$CLAUDE_SETTINGS'"
The status should be success
The output should include '$HOME/.claude/hooks/atuin-history.sh'
End
End

Describe 'non-interactive alias config'
It 'enables bash alias expansion in bashrcExtra'
When run bash -c "grep -F 'shopt -s expand_aliases' '$BASH_CONFIG'"
The status should be success
The output should include 'shopt -s expand_aliases'
End

It 'defines the zsh alias from envExtra so .zshenv sees it'
When run bash -c "grep -F \"alias rm='gomi'\" '$ZSH_CONFIG'"
The status should be success
The output should include "alias rm='gomi'"
End
End
End
