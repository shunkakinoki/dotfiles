#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'block-gh-settings.sh'
SCRIPT="$PWD/config/shared/hooks/block-gh-settings.sh"

Describe 'non-modifying commands'

It 'allows gh pr list'
Data '{"tool_input": {"command": "gh pr list"}}'
When run bash "$SCRIPT"
The status should be success
End

It 'allows gh repo view'
Data '{"tool_input": {"command": "gh repo view"}}'
When run bash "$SCRIPT"
The status should be success
End

It 'allows gh repo clone'
Data '{"tool_input": {"command": "gh repo clone owner/repo"}}'
When run bash "$SCRIPT"
The status should be success
End

It 'allows gh api GET'
Data '{"tool_input": {"command": "gh api /repos/owner/repo"}}'
When run bash "$SCRIPT"
The status should be success
End

It 'allows gh api -X POST to non-repo path'
Data '{"tool_input": {"command": "gh api -X POST /gists"}}'
When run bash "$SCRIPT"
The status should be success
End

End

Describe 'blocked gh repo subcommands'

It 'blocks gh repo delete'
Data '{"tool_input": {"command": "gh repo delete owner/repo"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks gh repo rename'
Data '{"tool_input": {"command": "gh repo rename new-name"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks gh repo archive'
Data '{"tool_input": {"command": "gh repo archive owner/repo"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks gh repo transfer'
Data '{"tool_input": {"command": "gh repo transfer owner/repo new-owner"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks gh repo edit'
Data '{"tool_input": {"command": "gh repo edit --description new-desc"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

End

Describe 'blocked gh api mutations on /repos/'

It 'blocks gh api -X PATCH /repos/...'
Data '{"tool_input": {"command": "gh api -X PATCH /repos/owner/repo"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks gh api -X DELETE /repos/...'
Data '{"tool_input": {"command": "gh api -X DELETE /repos/owner/repo/branches/main/protection"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks gh api -X PUT /repos/...'
Data '{"tool_input": {"command": "gh api -X PUT /repos/owner/repo/collaborators/user"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

End

Describe 'codex input format'

It 'blocks codex-style input with .command key'
Data '{"command": "gh repo delete owner/repo"}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

End

Describe 'edge cases'

It 'passes with empty input'
Data '{}'
When run bash "$SCRIPT"
The status should be success
End

It 'passes with empty command'
Data '{"tool_input": {"command": ""}}'
When run bash "$SCRIPT"
The status should be success
End

End

End
