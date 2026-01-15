#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'install-skills.sh'
SCRIPT="$PWD/config/claude/install-skills.sh"

Describe 'script structure'
It 'has valid bash syntax'
When run bash -n "$SCRIPT"
The status should be success
End

It 'uses strict mode'
When run grep -q 'set -euo pipefail' "$SCRIPT"
The status should be success
End

It 'has executable permission'
When run test -x "$SCRIPT"
The status should be success
End
End

Describe 'npx add-skill invocation'
setup() {
  mock_bin_setup npx
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'calls npx add-skill with correct arguments'
When run bash "$SCRIPT"
The status should be success
The output should include 'Installing agent skills'
End

It 'passes vercel-labs/agent-skills as source'
When run bash -c 'bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'vercel-labs/agent-skills'
End

It 'specifies claude-code as target agent'
When run bash -c 'bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include '--agent claude-code'
End

It 'includes vercel-react-best-practices skill'
When run bash -c 'bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'vercel-react-best-practices'
End

It 'includes web-design-guidelines skill'
When run bash -c 'bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'web-design-guidelines'
End

It 'uses --yes flag for non-interactive mode'
When run bash -c 'bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include '--yes'
End
End
End
