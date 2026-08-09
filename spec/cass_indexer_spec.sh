#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'cass/daily.sh'
SCRIPT="$PWD/home-manager/services/cass/daily.sh"

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

Describe 'cass commands'
It 'runs sources sync'
When run bash -c "cat '$SCRIPT'"
The output should include 'sources sync'
End

It 'runs analytics rebuild'
When run bash -c "cat '$SCRIPT'"
The output should include 'analytics rebuild'
End

It 'uses ~/.local/bin/cass path'
When run bash -c "cat '$SCRIPT'"
The output should include '.local/bin/cass'
End

It 'checks cass binary exists before running'
When run bash -c "cat '$SCRIPT'"
The output should include '! -x'
End
End

End

Describe 'cass/hydrate.sh'
HYDRATE="$PWD/home-manager/programs/cass/hydrate.sh"

render() {
  rm -rf "$SHELLSPEC_TMPBASE/cass-home"
  mkdir -p "$SHELLSPEC_TMPBASE/cass-home"
  env -u HOSTNAME HOME="$SHELLSPEC_TMPBASE/cass-home" HOST="$1" bash "$HYDRATE" 2>/dev/null
  if [ "$(uname -s)" = "Darwin" ]; then
    cat "$SHELLSPEC_TMPBASE/cass-home/Library/Application Support/cass/sources.toml"
  else
    cat "$SHELLSPEC_TMPBASE/cass-home/.config/cass/sources.toml"
  fi
}

Describe 'script properties'
It 'uses strict mode'
When run bash -c "head -5 '$HYDRATE'"
The output should include 'set -euo pipefail'
End
End

Describe 'peer selection'
It 'gives kyber the matic source only'
When call render kyber
The output should include 'shunkakinoki@matic'
The output should not include 'ubuntu@kyber'
End

It 'resolves the kyber provider hostname alias'
When call render c2-small-x86-chi-1
The output should include 'shunkakinoki@matic'
The output should not include 'ubuntu@kyber'
End

It 'gives matic the kyber source only'
When call render matic
The output should include 'ubuntu@kyber'
The output should not include 'shunkakinoki@matic'
End

It 'gives non-peer hosts every source'
When call render galactica
The output should include 'ubuntu@kyber'
The output should include 'shunkakinoki@matic'
End
End
End
