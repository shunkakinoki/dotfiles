#!/usr/bin/env bash
Describe 'managed Codex configuration'
It 'disables startup update prompts in config.toml'
When run grep -E '^check_for_update_on_startup = false$' "$PWD/config/codex/config.toml"
The status should be success
The output should include 'check_for_update_on_startup = false'
End

It 'disables startup update prompts in config.tpl.toml'
When run grep -E '^check_for_update_on_startup = false$' "$PWD/config/codex/config.tpl.toml"
The status should be success
The output should include 'check_for_update_on_startup = false'
End
End
