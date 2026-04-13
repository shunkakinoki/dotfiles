#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/services/obsidian/obsidian-git-trigger.sh'
SCRIPT="$PWD/home-manager/services/obsidian/obsidian-git-trigger.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'passes bash syntax check after replacing placeholders'
When run bash -c "sed -e 's|@curl@|/usr|g' -e 's|@jq@|/usr|g' -e 's|@websocat@|/usr|g' '$SCRIPT' | bash -n"
The status should be success
End
End

Describe 'placeholder references'
It 'references curl via placeholder'
When run bash -c "grep '@curl@' '$SCRIPT'"
The output should include '@curl@'
End

It 'references jq via placeholder'
When run bash -c "grep '@jq@' '$SCRIPT'"
The output should include '@jq@'
End

It 'references websocat via placeholder'
When run bash -c "grep '@websocat@' '$SCRIPT'"
The output should include '@websocat@'
End
End

Describe 'CDP integration'
It 'connects to CDP on port 9222'
When run bash -c "grep '9222' '$SCRIPT'"
The output should include '9222'
End

It 'triggers doAutoCommitAndSync'
When run bash -c "grep 'doAutoCommitAndSync' '$SCRIPT'"
The output should include 'doAutoCommitAndSync'
End
End

End
