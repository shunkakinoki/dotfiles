#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'sync-rtk-rewrite.sh'
SCRIPT="$PWD/scripts/sync-rtk-rewrite.sh"

It 'is executable'
The path "$SCRIPT" should be executable
End

It 'contains curl to raw.githubusercontent.com'
When run bash -c "grep -q 'raw.githubusercontent.com/rtk-ai/rtk' '$SCRIPT' && echo found"
The output should eq 'found'
End

It 'shared rtk-rewrite.sh exists and is executable'
The path "$PWD/config/shared/hooks/rtk-rewrite.sh" should be executable
End

It 'no agent-specific rtk-rewrite.sh copies remain'
When run bash -c "
  for path in \
    '$PWD/config/claude/hooks/rtk-rewrite.sh' \
    '$PWD/config/codex/hooks/rtk-rewrite.sh' \
    '$PWD/config/copilot/hooks/rtk-rewrite.sh'; do
    [ -e \"\$path\" ] && echo \"unexpected: \$path\"
  done
  exit 0
"
The output should eq ''
End
End
