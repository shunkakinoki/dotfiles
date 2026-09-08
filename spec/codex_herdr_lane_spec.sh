#!/usr/bin/env bash
# shellcheck disable=SC2016

Describe 'Codex Herdr native lane hooks'
CODEX_HOOKS="$PWD/generated/hooks/moshi/codex/hooks.json"

It 'registers SessionStart only for native startup and resume'
When run jq -e '[.hooks.SessionStart[] | select(.matcher == "startup|resume") | .hooks[]?.command] | any(. == "bun scripts/herdr-lane.ts hook")' "$CODEX_HOOKS"
The status should be success
The output should eq 'true'
End

It 'registers UserPromptSubmit with the native lane command'
When run jq -e '[.hooks.UserPromptSubmit[]?.hooks[]?.command] | any(. == "bun scripts/herdr-lane.ts hook")' "$CODEX_HOOKS"
The status should be success
The output should eq 'true'
End

It 'preserves the existing Codex hook fixture'
When run jq -e '[.. | objects | .command? // empty] as $registered | all(["moshi-hook codex-hook", "bd codex-hook SessionStart", "bd codex-hook UserPromptSubmit", "$HOME/dotfiles/config/shared/hooks/traces-agent-hook.sh session-start --agent codex # traces hook agent", "$HOME/dotfiles/config/shared/hooks/traces-agent-hook.sh prompt-submitted --agent codex # traces hook agent"][]; . as $expected | any($registered[]; . == $expected))' "$CODEX_HOOKS"
The status should be success
The output should eq 'true'
End

It 'does not add an actor or synthetic receipt fallback'
When run jq -e '[.. | objects | .command? // empty] | all(.[]; test("BEADS_ACTOR|parent.*export|receipt|generation"; "i") | not)' "$CODEX_HOOKS"
The status should be success
The output should eq 'true'
End
End
