#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/services/cliproxyapi/scripts/docker-start.sh'
SCRIPT="$PWD/home-manager/services/cliproxyapi/scripts/docker-start.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'passes bash syntax check after stripping placeholders'
When run bash -c "sed 's|@[a-z_]*@|/usr|g' '$SCRIPT' | bash -n"
The status should be success
End
End

Describe 'placeholder substitutions'
It 'references @bash@'
When run bash -c "grep '@bash@' '$SCRIPT'"
The output should include '@bash@'
End

It 'references @start_script@'
When run bash -c "grep '@start_script@' '$SCRIPT'"
The output should include '@start_script@'
End

It 'references @docker@'
When run bash -c "grep '@docker@' '$SCRIPT'"
The output should include '@docker@'
End
End

Describe 'docker access strategy'
It 'tries docker directly first'
When run bash -c "grep 'docker info' '$SCRIPT'"
The output should include 'docker info'
End

It 'falls back to NixOS sg wrapper'
When run bash -c "grep '/run/wrappers/bin/sg' '$SCRIPT'"
The output should include '/run/wrappers/bin/sg'
End

It 'falls back to system sg'
When run bash -c "grep '/usr/bin/sg' '$SCRIPT'"
The output should include '/usr/bin/sg'
End

It 'errors when no docker access available'
When run bash -c "grep 'Cannot access Docker' '$SCRIPT'"
The output should include 'Cannot access Docker'
End
End

End
