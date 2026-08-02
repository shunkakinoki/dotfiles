#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'config/caam'
DEFAULT_NIX="$PWD/config/caam/default.nix"
SCRIPT="$PWD/config/caam/hydrate.sh"
TEMPLATE="$PWD/config/caam/config.template.yaml"

It 'is imported by the shared config module'
When run grep -F './caam' "$PWD/config/default.nix"
The output should include './caam'
End

It 'hydrates only on Kyber and Matic'
When run cat "$DEFAULT_NIX"
The output should include 'inputs.host.isKyber || inputs.host.isMatic'
The output should include 'lib.mkIf managedHost'
End

It 'passes the host-derived rotation value to the hydrator'
When run cat "$DEFAULT_NIX"
The output should include 'autoRotate = if managedHost then "true" else "false"'
End

It 'leaves shell integration unmanaged'
When run grep -F 'programs.fish.interactiveShellInit' "$DEFAULT_NIX"
The status should be failure
End

It 'does not manage credential vault data'
When run grep -E 'home\.file.*vault|xdg\.dataFile.*caam' "$DEFAULT_NIX"
The status should be failure
End

Describe 'hydrate.sh'
setup_hydrate() {
  TEMP_HOME=$(mktemp -d)
  PREPROCESSED_SCRIPT="$TEMP_HOME/hydrate.sh"
  sed \
    -e 's|@sed@|sed|g' \
    -e 's|@template@|'"$TEMPLATE"'|g' \
    -e 's|@autoRotate@|true|g' \
    "$SCRIPT" >"$PREPROCESSED_SCRIPT"
  chmod +x "$PREPROCESSED_SCRIPT"
}

cleanup_hydrate() {
  rm -rf "$TEMP_HOME"
}

Before 'setup_hydrate'
After 'cleanup_hydrate'

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'hydrates smart rotation and cooldown settings'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; cat "'"$TEMP_HOME"'/.caam/config.yaml"'
The status should be success
The output should include 'enabled: true'
The output should include 'algorithm: smart'
The output should include 'track_limit_hits: true'
The output should not include '__AUTO_ROTATE__'
End

It 'restricts config file permissions to the owner'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; stat -c "%a" "'"$TEMP_HOME"'/.caam/config.yaml" 2>/dev/null || stat -f "%OLp" "'"$TEMP_HOME"'/.caam/config.yaml"'
The output should eq '600'
End
End
End
