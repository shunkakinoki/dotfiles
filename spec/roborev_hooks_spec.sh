#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'config/shared/hooks/roborev-agent.sh'
SCRIPT="$PWD/config/shared/hooks/roborev-agent.sh"

setup_hook() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/bin" "$TEMP_HOME/repo"
  CALLS="$TEMP_HOME/calls"
  : >"$CALLS"
  printf '[review.panels.full]\nmembers = ["opencode"]\n' >"$TEMP_HOME/repo/.roborev.toml"

  cat >"$TEMP_HOME/bin/roborev" <<'SH'
#!/usr/bin/env bash
if [[ " $* " == *" agent-hook run "* ]]; then
  cat >/dev/null
  printf '{"continue":true}\n'
elif [[ " $* " == *" review "* ]]; then
  printf 'roborev %s\n' "$*" >>"$CALLS"
  [ "${ROBOREV_REVIEW_FAIL:-0}" = "1" ] && exit 1
  printf 'No issues found.\n'
fi
SH
  cat >"$TEMP_HOME/bin/git" <<'SH'
#!/usr/bin/env bash
if [[ " $* " == *" --show-toplevel "* ]]; then
  printf '%s\n' "$REPO_PATH"
elif [[ " $* " == *" merge-base "* ]]; then
  printf '%s\n' "$BASE_OID"
else
  printf '%s\n' "$HEAD_OID"
fi
SH
  cat >"$TEMP_HOME/bin/gh" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "pr" ]; then
  if [ "${2:-}" = "view" ]; then
    printf '{"number":42,"state":"OPEN","baseRefOid":"%s","headRefOid":"%s"}\n' "$BASE_OID" "$HEAD_OID"
  else
    printf 'gh %s\n' "$*" >>"$CALLS"
  fi
fi
SH
  chmod +x "$TEMP_HOME/bin/roborev" "$TEMP_HOME/bin/git" "$TEMP_HOME/bin/gh"

  export CALLS
  export REPO_PATH="$TEMP_HOME/repo"
  export BASE_OID=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  export HEAD_OID=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  export ROBOREV_BIN="$TEMP_HOME/bin/roborev"
  export GIT_BIN="$TEMP_HOME/bin/git"
  export GH_BIN="$TEMP_HOME/bin/gh"
  export JQ_BIN=jq
  export ROBOREV_AGENT_HOOK_SYNC=1
  export ROBOREV_AGENT_FULL_REVIEW_STATE_DIR="$TEMP_HOME/state"
}

cleanup_hook() {
  rm -rf "$TEMP_HOME"
}

Before 'setup_hook'
After 'cleanup_hook'

It 'uses the local RoboRev daemon and preserves hook output'
Data '{"session_id":"s1","hook_event_name":"PostToolUse","cwd":"/tmp","tool_input":{"command":"true"}}'
When run bash "$SCRIPT"
The status should be success
The output should eq '{"continue":true}'
End

It 'starts one full panel after a pushed PR and posts a separate comment'
Data '{"session_id":"s1","hook_event_name":"PostToolUse","cwd":"__REPO__","tool_input":{"command":"git push origin HEAD"}}'
When run bash -c 'sed "s|__REPO__|$REPO_PATH|" | bash "$1"; printf "calls:\n"; cat "$CALLS"' _ "$SCRIPT"
The status should be success
The output should include '{"continue":true}'
The output should include '--sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb --panel full'
The output should include 'gh pr comment 42 --body ## RoboRev Full Panel'
End

It 'does not comment when the full panel fails'
export ROBOREV_REVIEW_FAIL=1
Data '{"session_id":"s1","hook_event_name":"Stop","cwd":"__REPO__"}'
When run bash -c 'sed "s|__REPO__|$REPO_PATH|" | bash "$1" >/dev/null || true; grep -c -- "gh pr comment" "$CALLS" || true' _ "$SCRIPT"
The status should be success
The output should include '0'
End

It 'preserves hook output when the full panel fails'
export ROBOREV_REVIEW_FAIL=1
Data '{"session_id":"s1","hook_event_name":"Stop","cwd":"__REPO__"}'
When run bash -c 'sed "s|__REPO__|$REPO_PATH|" | bash "$1"' _ "$SCRIPT"
The status should be success
The output should eq '{"continue":true}'
End

It 'runs the production background path'
unset ROBOREV_AGENT_HOOK_SYNC
Data '{"session_id":"s1","hook_event_name":"Stop","cwd":"__REPO__"}'
When run bash -c 'sed "s|__REPO__|$REPO_PATH|" | bash "$1" >/dev/null; for _ in {1..50}; do grep -q "gh pr comment" "$CALLS" && break; sleep 0.05; done; grep -c "gh pr comment" "$CALLS"' _ "$SCRIPT"
The status should be success
The output should eq '1'
End

It 'deduplicates repeated Stop events for the same PR head'
When run bash -c 'payload="{\"session_id\":\"s1\",\"hook_event_name\":\"Stop\",\"cwd\":\"$REPO_PATH\"}"; printf "%s" "$payload" | bash "$1" >/dev/null; printf "%s" "$payload" | bash "$1"; grep -c -- "--panel full" "$CALLS"' _ "$SCRIPT"
The status should be success
The output should include '{"continue":true}'
The output should include '1'
End

It 'skips repositories that do not define the full panel'
rm -f "$REPO_PATH/.roborev.toml"
Data '{"session_id":"s1","hook_event_name":"Stop","cwd":"__REPO__"}'
When run bash -c 'sed "s|__REPO__|$REPO_PATH|" | bash "$1" >/dev/null; grep -c -- "--panel full" "$CALLS" || true' _ "$SCRIPT"
The status should be success
The output should eq '0'
End

Describe 'config/factory/activate-settings.sh'
It 'recognizes the managed RoboRev hook'
When run grep -F 'dotfiles/config/shared/hooks/roborev-agent.sh' "$PWD/config/factory/activate-settings.sh"
The output should include 'dotfiles/config/shared/hooks/roborev-agent.sh'
End
End
End
