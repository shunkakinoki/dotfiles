#!/usr/bin/env bash

Describe 'config/shared/hooks/roborev-agent.sh'
It 'uses the local RoboRev daemon'
When run grep -F '127.0.0.1:7373' "$PWD/config/shared/hooks/roborev-agent.sh"
The output should include '127.0.0.1:7373'
End

Describe 'config/factory/activate-settings.sh'
SCRIPT="$PWD/config/factory/activate-settings.sh"
SETTINGS="$PWD/config/factory/settings.json"

It 'recognizes the managed RoboRev hook'
When run grep -F 'dotfiles/config/shared/hooks/roborev-agent.sh' "$SCRIPT"
The output should include 'dotfiles/config/shared/hooks/roborev-agent.sh'
End

It 'registers DeepSeek Flash as the Factory session default via CLIProxy'
When run jq -e '.sessionDefaultSettings.model == "custom:deepseek-v4-flash-0" and (.customModels | length) == 1 and .customModels[0].id == "custom:deepseek-v4-flash-0" and .customModels[0].baseUrl == "https://cliproxy.shunkakinoki.com/v1" and .customModels[0].apiKey == "CLIPROXY_API_KEY"' "$SETTINGS"
The status should be success
The output should equal 'true'
End

It 'replaces every managed custom model id on merge'
When run grep -F 'map(.id)) as $managed_ids' "$SCRIPT"
The output should include '$managed_ids'
End

It 'drops the retired local Ollama Gemma custom model'
When run grep -F 'custom:gemma3:4b-0' "$SCRIPT"
The output should include 'custom:gemma3:4b-0'
End
End
End
