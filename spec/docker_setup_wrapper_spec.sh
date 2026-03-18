#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/services/docker/docker-setup.sh'
SCRIPT="$PWD/home-manager/services/docker/docker-setup.sh"

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
It 'uses exec to delegate to setup script'
When run bash -c "grep 'exec' '$SCRIPT'"
The output should include 'exec'
End

It 'references @setup_docker_script@'
When run bash -c "grep '@setup_docker_script@' '$SCRIPT'"
The output should include '@setup_docker_script@'
End
End

End
