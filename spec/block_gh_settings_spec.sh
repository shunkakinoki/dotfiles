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

It 'allows a pull request API mutation'
Data '{"tool_input": {"command": "gh api -X POST /repos/owner/repo/pulls -f title=test"}}'
When run bash "$SCRIPT"
The status should be success
End

It 'allows an issue comment API mutation'
Data '{"tool_input": {"command": "gh api --method POST /repos/owner/repo/issues/1/comments -f body=test"}}'
When run bash "$SCRIPT"
The status should be success
End

It 'allows a GraphQL query'
Data '{"tool_input": {"command": "gh api graphql -f query=queryViewer"}}'
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

It 'blocks gh api --method DELETE'
Data '{"tool_input": {"command": "gh api --method DELETE /repos/owner/repo/rulesets/1"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks gh api --method=PATCH'
Data '{"tool_input": {"command": "gh api --method=PATCH /repos/owner/repo -f visibility=private"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks compact -XDELETE'
Data '{"tool_input": {"command": "gh api -XDELETE /repos/owner/repo/hooks/1"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks an implicit POST from a field'
Data '{"tool_input": {"command": "gh api /repos/owner/repo/rulesets -f name=unsafe"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks an implicit POST from an input body'
Data '{"tool_input": {"command": "gh api /repos/owner/repo/actions/permissions --input payload.json"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

End

Describe 'GraphQL mutations'

It 'blocks an inline mutation'
Data '{"tool_input": {"command": "gh api graphql -f query=\"mutation UpdateRepository { updateRepository }\""}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks a GraphQL input file because it may contain a mutation'
Data '{"tool_input": {"command": "gh api graphql --input mutation.json"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End
End

Describe 'settings-oriented commands'

It 'blocks repository secret changes'
Data '{"tool_input": {"command": "gh secret set TOKEN"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks repository variable changes'
Data '{"tool_input": {"command": "gh variable delete FLAG"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks deploy-key changes'
Data '{"tool_input": {"command": "gh repo deploy-key add key.pub"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks workflow disablement'
Data '{"tool_input": {"command": "gh workflow disable build.yml"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End
End

Describe 'direct HTTP clients'

It 'blocks curl method mutations'
Data '{"tool_input": {"command": "curl -X PATCH https://api.github.com/repos/owner/repo -d visibility=private"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks curl implicit POSTs'
Data '{"tool_input": {"command": "curl -d name=test https://api.github.com/repos/owner/repo/rulesets"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks curl long-form request methods'
Data '{"tool_input": {"command": "curl --request PATCH https://api.github.com/repos/owner/repo --json {}"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks HTTPie mutations'
Data '{"tool_input": {"command": "http DELETE https://api.github.com/repos/owner/repo/hooks/1"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks xh mutations'
Data '{"tool_input": {"command": "xh PUT https://api.github.com/repos/owner/repo/actions/permissions"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks HTTPie implicit POSTs'
Data '{"tool_input": {"command": "http https://api.github.com/repos/owner/repo/topics names:=[]"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks wget mutations against GitHub Enterprise'
Data '{"tool_input": {"command": "wget --method=DELETE https://github.example/api/v3/repos/owner/repo/rulesets/1"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'allows direct issue comments'
Data '{"tool_input": {"command": "curl -X POST https://api.github.com/repos/owner/repo/issues/1/comments -d body=test"}}'
When run bash "$SCRIPT"
The status should be success
End
End

Describe 'codex input format'

It 'blocks codex-style input with .command key'
Data '{"command": "gh repo delete owner/repo"}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks nested Codex tool input'
Data '{"tool": {"input": {"command": "gh repo edit --enable-wiki"}}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

End

Describe 'copilot input format'

It 'blocks Copilot gh repo edit'
Data '{"toolName": "shell", "toolArgs": {"command": "gh repo edit owner/repo --visibility private"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks camel-case tool input'
Data '{"toolInput": {"command": "gh repo edit --enable-wiki"}}'
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
