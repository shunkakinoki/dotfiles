#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'docker-postgres/start-postgres.sh'
SCRIPT="$PWD/home-manager/services/docker-postgres/start-postgres.sh"

Describe 'script properties'
It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End
End

Describe 'container configuration'
It 'uses postgres:18 image'
When run bash -c "cat '$SCRIPT'"
The output should include 'IMAGE="postgres:18"'
End

It 'uses container name postgres'
When run bash -c "cat '$SCRIPT'"
The output should include 'CONTAINER_NAME="postgres"'
End

It 'maps port 5432'
When run bash -c "cat '$SCRIPT'"
The output should include 'HOST_PORT="5432"'
End

It 'sets POSTGRES_DB=trails_api'
When run bash -c "cat '$SCRIPT'"
The output should include 'POSTGRES_DB=trails_api'
End

It 'sets POSTGRES_PASSWORD=postgres'
When run bash -c "cat '$SCRIPT'"
The output should include 'POSTGRES_PASSWORD=postgres'
End
End

Describe 'docker daemon wait logic'
It 'defines wait_for_docker function'
When run bash -c "cat '$SCRIPT'"
The output should include 'wait_for_docker'
End

It 'checks docker info for readiness'
When run bash -c "cat '$SCRIPT'"
The output should include 'docker info'
End

It 'has configurable retry settings'
When run bash -c "cat '$SCRIPT'"
The output should include 'MAX_RETRIES='
End
End

Describe 'container management'
It 'inspects container state before acting'
When run bash -c "cat '$SCRIPT'"
The output should include 'docker container inspect'
End

It 'starts existing stopped containers'
When run bash -c "cat '$SCRIPT'"
The output should include 'docker start'
End

It 'creates new container with docker run'
When run bash -c "cat '$SCRIPT'"
The output should include 'docker run -d'
End

It 'sets restart policy to unless-stopped'
When run bash -c "cat '$SCRIPT'"
The output should include '--restart=unless-stopped'
End
End

Describe 'health verification'
It 'verifies postgres with pg_isready'
When run bash -c "cat '$SCRIPT'"
The output should include 'pg_isready'
End
End

End
