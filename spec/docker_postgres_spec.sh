#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'Postgres private bootstrap'
SCRIPT="$PWD/home-manager/services/docker-postgres/start-postgres.sh"
setup() {
  WORK=$(mktemp -d)
  export POSTGRES_PASSWORD_FILE="$WORK/password" DOCKER_LOG="$WORK/docker.log"
  export PATH="$WORK/bin:$PATH" SCENARIO=new
  mkdir -p "$WORK/bin"
  cat >"$WORK/bin/docker" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$DOCKER_LOG"
case "$1 $2" in
  'info ') exit 0 ;;
  'container inspect')
    [ "$SCENARIO" = new ] && exit 1
    case "$*" in
      *State.Status*) printf '%s\n' "${CONTAINER_STATE:-running}" ;;
      *PortBindings*) printf '%s\n' "${BINDING:-127.0.0.1:5432}" ;;
      *Config.Env*) [ "$SCENARIO" != trust-env ] || printf 'trust\n' ;;
    esac
    exit 0 ;;
  'exec postgres')
    if [ "$3" = pg_isready ]; then [ "$SCENARIO" != unhealthy ]; exit; fi
    [ "$SCENARIO" != query-error ] || exit 1
    if [ "$SCENARIO" = trust-hba ]; then printf '1\n'; else printf '0\n'; fi ;;
esac
MOCK
  printf '#!/usr/bin/env bash\nexit 0\n' >"$WORK/bin/sleep"
  chmod +x "$WORK/bin/docker" "$WORK/bin/sleep"
}
cleanup() {
  rm -f "$WORK/password" "$WORK/docker.log" "$WORK/bin/docker" "$WORK/bin/sleep"
  rmdir "$WORK/bin" "$WORK"
}
Before 'setup'
After 'cleanup'

It 'creates an isolated authenticated database'
When run bash "$SCRIPT"
The status should be success
The output should include 'Done'
The contents of file "$DOCKER_LOG" should include '127.0.0.1:5432:5432'
The contents of file "$DOCKER_LOG" should include 'POSTGRES_HOST_AUTH_METHOD=scram-sha-256'
The contents of file "$DOCKER_LOG" should include 'POSTGRES_PASSWORD_FILE=/run/secrets/postgres-password'
The contents of file "$DOCKER_LOG" should include 'type=volume,src=postgres-data,dst=/var/lib/postgresql'
The file "$POSTGRES_PASSWORD_FILE" should be exist
End

verify_secret() {
  bash "$SCRIPT" >/dev/null &&
    test "$(wc -c <"$POSTGRES_PASSWORD_FILE" | tr -d ' ')" = 64 &&
    test "$(portable_stat_perms "$POSTGRES_PASSWORD_FILE")" = 600 &&
    ! grep -qF "$(cat "$POSTGRES_PASSWORD_FILE")" "$DOCKER_LOG"
}
It 'keeps its generated credential private and out of command arguments'
When call verify_secret
The status should be success
End

It 'can explicitly reuse a preserved data volume'
export POSTGRES_DATA_VOLUME=preserved-volume
When run bash "$SCRIPT"
The status should be success
The output should include 'Done'
The contents of file "$DOCKER_LOG" should include 'type=volume,src=preserved-volume,dst=/var/lib/postgresql'
End

It 'refuses an existing wildcard publication without changing the container'
export SCENARIO=existing BINDING=0.0.0.0:5432
When run bash "$SCRIPT"
The status should be failure
The output should include 'storage-preserving security migration'
The contents of file "$DOCKER_LOG" should not include 'run -d'
The contents of file "$DOCKER_LOG" should not include 'start postgres'
The contents of file "$DOCKER_LOG" should not include 'rm '
End

It 'refuses a stopped container initialized with trust authentication'
export SCENARIO=trust-env CONTAINER_STATE=exited
When run bash "$SCRIPT"
The status should be failure
The output should include 'storage-preserving security migration'
The contents of file "$DOCKER_LOG" should not include 'start postgres'
End

It 'rejects trust rules in an otherwise correctly bound running database'
export SCENARIO=trust-hba
When run bash "$SCRIPT"
The status should be failure
The output should include 'unsafe or invalid network authentication'
End

It 'reports authentication inspection failure instead of success'
export SCENARIO=query-error
When run bash "$SCRIPT"
The status should be failure
The output should not include 'Done'
End

It 'fails when the database never becomes ready'
export SCENARIO=unhealthy
When run bash "$SCRIPT"
The status should be failure
The output should include 'did not become ready'
End

It 'starts a safely configured stopped container'
export SCENARIO=existing CONTAINER_STATE=exited
When run bash "$SCRIPT"
The status should be success
The output should include 'Done'
The contents of file "$DOCKER_LOG" should include 'start postgres'
End
End
