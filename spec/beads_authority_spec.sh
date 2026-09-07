#!/usr/bin/env bash
# shellcheck disable=SC2329
Describe 'Beads GUI client environment'
setup() {
  TEST_ROOT=$(mktemp -d)
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s " "$@"; printf "\n"' >"$TEST_ROOT/launchctl"
  chmod +x "$TEST_ROOT/launchctl"
  sed -e "s|/bin/launchctl|$TEST_ROOT/launchctl|g" -e 's|@doltServerHost@|kyber.tail950b36.ts.net|g' home-manager/services/dolt/client-environment.sh >"$TEST_ROOT/client.sh"
}
cleanup() { rm -rf "$TEST_ROOT"; }
Before setup
After cleanup
It 'routes new GUI clients to Kyber and removes replica environment'
When run bash "$TEST_ROOT/client.sh"
The status should be success
The output should include 'unsetenv BEADS_DOLT_DATA_DIR'
The output should include 'unsetenv BEADS_FEDERATION_HUB'
The output should include 'setenv BEADS_DOLT_SERVER_HOST kyber.tail950b36.ts.net'
The output should include 'setenv BEADS_DOLT_AUTO_START 0'
The output should include 'setenv BEADS_NODE_ID kyber'
The output should include 'setenv BEADS_DOLT_SERVER_USER beads'
The output should include 'setenv DOLT_CLI_USER beads'
End
End
