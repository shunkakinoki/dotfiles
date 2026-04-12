#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/services/obsidian/obsidian-headless.sh'
SCRIPT="$PWD/home-manager/services/obsidian/obsidian-headless.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'passes bash syntax check after replacing placeholders'
When run bash -c "sed -e 's|@xvfbRun@|/usr|g' -e 's|@obsidian@|/usr|g' '$SCRIPT' | bash -n"
The status should be success
End
End

Describe 'placeholder references'
It 'references xvfb-run via placeholder'
When run bash -c "grep '@xvfbRun@' '$SCRIPT'"
The output should include '@xvfbRun@'
End

It 'references obsidian via placeholder'
When run bash -c "grep '@obsidian@' '$SCRIPT'"
The output should include '@obsidian@'
End

It 'uses exec to replace the process'
When run bash -c "grep '^exec ' '$SCRIPT'"
The output should include 'exec'
End

It 'passes all arguments through'
When run bash -c "grep '[\$]@' '$SCRIPT'"
The output should include '$@'
End

It 'uses xvfb-run with auto-servernum flag'
When run bash -c "grep '\\-a' '$SCRIPT'"
The output should include '-a'
End
End

End
