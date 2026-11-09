#!/usr/bin/env bash

Describe 'Beads agent hook configuration'

CLAUDE_SETTINGS="$PWD/config/claude/settings.json"
CODEX_HOOKS="$PWD/config/codex/hooks.json"
CURSOR_HOOKS="$PWD/config/cursor/hooks.json"
GEMINI_SETTINGS="$PWD/config/gemini/settings.json"
DEVIN_HOOKS="$PWD/config/devin/hooks.v1.json"

# Beads context costs a storage open per call, so it stays off the session and
# prompt paths and runs only around compaction.
has_no_beads_hook() {
  ! jq -e --arg event "$2" '[.hooks[$event][]? | (.command, (.hooks[]?.command)) | strings] | any(test("\\|\\| bd "))' "$1" >/dev/null
}

has_codex_hook() {
  jq -e --arg event "$1" --arg command "$2" '[.hooks[$event][]?.hooks[]?.command] | any(. == $command)' "$CODEX_HOOKS" >/dev/null
}

has_cursor_hook() {
  jq -e --arg event "$1" --arg command "$2" '[.hooks[$event][]?.command] | any(. == $command)' "$CURSOR_HOOKS" >/dev/null
}

It 'keeps Beads off Claude session start'
When call has_no_beads_hook "$CLAUDE_SETTINGS" 'SessionStart'
The status should be success
End

It 'keeps Beads off Gemini session start'
When call has_no_beads_hook "$GEMINI_SETTINGS" 'SessionStart'
The status should be success
End

It 'keeps Beads off Devin session start'
When call has_no_beads_hook "$DEVIN_HOOKS" 'SessionStart'
The status should be success
End

It 'keeps Beads off Codex session start'
When call has_no_beads_hook "$CODEX_HOOKS" 'SessionStart'
The status should be success
End

It 'keeps Beads off every Codex prompt'
When call has_no_beads_hook "$CODEX_HOOKS" 'UserPromptSubmit'
The status should be success
End

It 'keeps Beads off Cursor session start'
When call has_no_beads_hook "$CURSOR_HOOKS" 'sessionStart'
The status should be success
End

It 'keeps Beads off every Cursor tool use'
When call has_no_beads_hook "$CURSOR_HOOKS" 'postToolUse'
The status should be success
End

It 'checks Beads context before Codex compaction'
When call has_codex_hook 'PreCompact' '! command -v bd >/dev/null 2>&1 || bd codex-hook PreCompact'
The status should be success
End

It 'refreshes Beads context after Codex compaction'
When call has_codex_hook 'PostCompact' '! command -v bd >/dev/null 2>&1 || bd codex-hook PostCompact'
The status should be success
End

It 'installs the Cursor compaction recovery hooks'
When call has_cursor_hook 'preCompact' '! command -v bd >/dev/null 2>&1 || bd cursor-hook preCompact'
The status should be success
End

End
