#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/modules/yek/yek-shim.sh'
SCRIPT="$PWD/home-manager/modules/yek/yek-shim.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'passes bash syntax check after stripping placeholders'
When run bash -c "sed 's|@[a-z_]*@|/usr/bin/true|g' '$SCRIPT' | bash -n"
The status should be success
End
End

Describe 'delegation'
It 'uses exec to delegate'
When run bash -c "grep 'exec' '$SCRIPT'"
The output should include 'exec'
End

It 'references @bash@'
When run bash -c "grep '@bash@' '$SCRIPT'"
The output should include '@bash@'
End

It 'references @yek_wrapper_script@'
When run bash -c "grep '@yek_wrapper_script@' '$SCRIPT'"
The output should include '@yek_wrapper_script@'
End

It 'passes all arguments through'
When run bash -c "grep '\"\$@\"' '$SCRIPT'"
The output should include '"$@"'
End
End

End
