#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/services/docker/setup-docker.sh'
SCRIPT="$PWD/home-manager/services/docker/setup-docker.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "grep 'set -euo pipefail' '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'passes bash syntax check after stripping placeholders'
When run bash -c "sed 's|@[a-z_]*@|/usr|g' '$SCRIPT' | bash -n"
The status should be success
End
End

Describe 'placeholder substitutions'
It 'references @shadow@ for groups and usermod'
When run bash -c "grep '@shadow@' '$SCRIPT'"
The output should include '@shadow@'
End

It 'references @gnugrep@'
When run bash -c "grep '@gnugrep@' '$SCRIPT'"
The output should include '@gnugrep@'
End

It 'references @systemd@'
When run bash -c "grep '@systemd@' '$SCRIPT'"
The output should include '@systemd@'
End

It 'references @coreutils@'
When run bash -c "grep '@coreutils@' '$SCRIPT'"
The output should include '@coreutils@'
End

It 'references @docker_service_file@'
When run bash -c "grep '@docker_service_file@' '$SCRIPT'"
The output should include '@docker_service_file@'
End
End

Describe 'docker group management'
It 'checks group membership'
When run bash -c "grep 'docker group' '$SCRIPT'"
The output should include 'docker group'
End

It 'uses usermod to add user to docker group'
When run bash -c "grep 'usermod' '$SCRIPT'"
The output should include 'usermod'
End
End

Describe 'daemon management'
It 'checks if docker daemon is active'
When run bash -c "grep 'is-active' '$SCRIPT'"
The output should include 'is-active'
End

It 'installs service file to /etc/systemd'
When run bash -c "grep '/etc/systemd/system/docker.service' '$SCRIPT'"
The output should include '/etc/systemd/system/docker.service'
End

It 'enables docker on boot'
When run bash -c "grep 'enable docker' '$SCRIPT'"
The output should include 'enable docker'
End
End

End
