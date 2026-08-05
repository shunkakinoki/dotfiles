#!/usr/bin/env bash

Describe 'config/shared/hooks/roborev-agent.sh'
It 'uses the local RoboRev daemon'
When run grep -F '127.0.0.1:7373' "$PWD/config/shared/hooks/roborev-agent.sh"
The output should include '127.0.0.1:7373'
End

Describe 'config/factory/activate-settings.sh'
It 'recognizes the managed RoboRev hook'
When run grep -F 'dotfiles/config/shared/hooks/roborev-agent.sh' "$PWD/config/factory/activate-settings.sh"
The output should include 'dotfiles/config/shared/hooks/roborev-agent.sh'
End
End
End

Describe 'config/shared/hooks/roborev-post-commit.sh'
It 'submits the current repository to the local daemon'
When run grep -F 'post-commit --repo' "$PWD/config/shared/hooks/roborev-post-commit.sh"
The output should include 'post-commit --repo'
End
End
