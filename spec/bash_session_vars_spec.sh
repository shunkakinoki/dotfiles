#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'bash session variables in non-login shells'
BASH_CONFIG="$PWD/home-manager/programs/bash/default.nix"

It 'sources hm-session-vars.sh first in bashrcExtra, before .env and PATH exports'
When run bash -c "awk '/bashrcExtra = /{start=NR} /hm-session-vars.sh\"/{vars=NR} /shopt -s expand_aliases/{alias=NR} /load-env-file.sh\"\$/{env=NR} /export PATH=/{if (!path) path=NR} END{ if (start && vars > start && vars < alias && alias < env && env < path) print \"ok\"; else print \"bad start=\" start \" vars=\" vars \" alias=\" alias \" env=\" env \" path=\" path }' '$BASH_CONFIG'"
The output should eq 'ok'
End

Describe 'rendered source line'
setup() {
  TEST_HOME=$(mktemp -d)
  BASH_BIN=$(command -v bash)
  mkdir -p "$TEST_HOME/pkg/etc/profile.d"
  cat >"$TEST_HOME/pkg/etc/profile.d/hm-session-vars.sh" <<'EOF'
if [ -n "$__HM_SESS_VARS_SOURCED" ]; then return; fi
export __HM_SESS_VARS_SOURCED=1
export BEADS_NODE_ID="kyber"
EOF
  {
    grep -F 'hm-session-vars.sh"' "$BASH_CONFIG" |
      sed -e 's/^ *//' -e "s|\${config.home.sessionVariablesPackage}|$TEST_HOME/pkg|"
    printf '%s\n' '[[ $- == *i* ]] || return'
  } >"$TEST_HOME/.bashrc"
}
cleanup() { rm -rf "$TEST_HOME"; }
Before 'setup'
After 'cleanup'

It 'exports session variables to a non-interactive, non-login shell'
When run env -i HOME="$TEST_HOME" "$BASH_BIN" -c '. "$HOME/.bashrc"; printf "%s" "${BEADS_NODE_ID:-<unset>}"'
The status should be success
The output should eq 'kyber'
End
End
End
