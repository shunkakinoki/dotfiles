#!/usr/bin/env bash

Describe 'Beads agent hook configuration'

CLAUDE_SETTINGS="$PWD/config/claude/settings.json"
CODEX_HOOKS="$PWD/config/codex/hooks.json"
CURSOR_HOOKS="$PWD/config/cursor/hooks.json"
GEMINI_SETTINGS="$PWD/config/gemini/settings.json"

has_session_start_hook() {
  jq -e '[.hooks.SessionStart[]?.hooks[]?.command] | any(. == "bd prime --hook-json")' "$1" >/dev/null
}

has_codex_hook() {
  jq -e --arg event "$1" --arg command "$2" '[.hooks[$event][]?.hooks[]?.command] | any(. == $command)' "$CODEX_HOOKS" >/dev/null
}

has_cursor_hook() {
  jq -e --arg event "$1" --arg command "$2" '[.hooks[$event][]?.command] | any(. == $command)' "$CURSOR_HOOKS" >/dev/null
}

It 'uses the JSON envelope for Claude session context'
When call has_session_start_hook "$CLAUDE_SETTINGS"
The status should be success
End

It 'uses the JSON envelope for Gemini session context'
When call has_session_start_hook "$GEMINI_SETTINGS"
The status should be success
End

It 'installs the Codex compaction recovery lifecycle'
When call has_codex_hook 'SessionStart' 'bd codex-hook SessionStart'
The status should be success
End

It 'checks Beads context before Codex compaction'
When call has_codex_hook 'PreCompact' 'bd codex-hook PreCompact'
The status should be success
End

It 'refreshes Beads context after Codex compaction'
When call has_codex_hook 'PostCompact' 'bd codex-hook PostCompact'
The status should be success
End

It 'injects Beads context on the first Codex prompt after compaction'
When call has_codex_hook 'UserPromptSubmit' 'bd codex-hook UserPromptSubmit'
The status should be success
End

It 'installs the Cursor session context hook'
When call has_cursor_hook 'sessionStart' 'bd cursor-hook sessionStart'
The status should be success
End

It 'installs the Cursor compaction recovery hooks'
When call has_cursor_hook 'preCompact' 'bd cursor-hook preCompact'
The status should be success
End

It 're-injects Cursor context after compaction'
When call has_cursor_hook 'postToolUse' 'bd cursor-hook postToolUse'
The status should be success
End

End
