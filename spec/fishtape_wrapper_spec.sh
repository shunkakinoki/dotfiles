#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'scripts/fishtape-wrapper.sh'
SCRIPT="$PWD/scripts/fishtape-wrapper.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'passes bash syntax check after stripping placeholders'
When run bash -c "sed 's|@[a-z0-9_]*@|/usr|g' '$SCRIPT' | bash -n"
The status should be success
End
End

Describe 'placeholder substitutions'
It 'references @fish@'
When run bash -c "grep '@fish@' '$SCRIPT'"
The output should include '@fish@'
End

It 'references @fishtape_3_src@'
When run bash -c "grep '@fishtape_3_src@' '$SCRIPT'"
The output should include '@fishtape_3_src@'
End
End

Describe 'invocation'
It 'sources fishtape.fish'
When run bash -c "grep 'fishtape.fish' '$SCRIPT'"
The output should include 'fishtape.fish'
End

It 'uses exec to replace the process'
When run bash -c "grep '^exec' '$SCRIPT'"
The output should include 'exec'
End

It 'passes arguments through'
When run bash -c "grep '\"\$@\"' '$SCRIPT'"
The output should include '"$@"'
End
End

End
