#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'config/caam'
DEFAULT_NIX="$PWD/config/caam/default.nix"
SCRIPT="$PWD/config/caam/hydrate.sh"
TEMPLATE="$PWD/config/caam/config.template.yaml"
FISH_NIX="$PWD/home-manager/programs/fish/default.nix"
BASH_NIX="$PWD/home-manager/programs/bash/default.nix"
ZSH_NIX="$PWD/home-manager/programs/zsh/default.nix"
CURSOR_NIX="$PWD/config/cursor/default.nix"

It 'is imported by the shared config module'
When run grep -F './caam' "$PWD/config/default.nix"
The output should include './caam'
End

It 'hydrates on every host'
When run cat "$DEFAULT_NIX"
The output should not include 'inputs.host'
The output should not include 'lib.mkIf'
End

It 'always enables automatic rotation'
When run cat "$DEFAULT_NIX"
The output should include 'autoRotate = "true"'
End

It 'keeps shell environment ownership outside the CAAM module'
When run grep -F 'CAAM_ROTATION_ENABLED' "$DEFAULT_NIX"
The status should be failure
End

It 'exports the rotation flag from each shell module'
When run bash -c "cat '$FISH_NIX' '$BASH_NIX' '$ZSH_NIX'"
The output should include 'set -gx CAAM_ROTATION_ENABLED 1'
The output should include 'CAAM_ROTATION_ENABLED = "1"'
The output should include 'export CAAM_ROTATION_ENABLED=1'
End

It 'does not manage credential vault data'
When run grep -E 'home\.file.*vault|xdg\.dataFile.*caam' "$DEFAULT_NIX"
The status should be failure
End

It 'exposes cursor-agent as cursor on headless Linux hosts'
When run cat "$CURSOR_NIX"
The output should include 'pkgs.stdenv.isLinux'
The output should include '.local/bin/cursor-agent'
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

It 'bridges global Cursor auth to the XDG path'
When run bash -c 'mkdir -p "'"$TEMP_HOME"'/.cursor"; touch "'"$TEMP_HOME"'/.cursor/auth.json"; HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; readlink "'"$TEMP_HOME"'/.config/cursor/auth.json"'
The status should be success
The output should eq '../../.cursor/auth.json'
End

It 'bridges isolated Cursor profile auth to the XDG path'
When run bash -c 'profile_home="'"$TEMP_HOME"'/.local/share/caam/profiles/cursor/work/home"; mkdir -p "$profile_home/.cursor"; touch "$profile_home/.cursor/auth.json"; HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; readlink "$profile_home/.config/cursor/auth.json"'
The status should be success
The output should eq '../../.cursor/auth.json'
End

It 'preserves a conflicting Cursor XDG credential'
When run bash -c 'mkdir -p "'"$TEMP_HOME"'/.cursor" "'"$TEMP_HOME"'/.config/cursor"; printf source >"'"$TEMP_HOME"'/.cursor/auth.json"; printf target >"'"$TEMP_HOME"'/.config/cursor/auth.json"; HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; cat "'"$TEMP_HOME"'/.config/cursor/auth.json"'
The status should be success
The output should eq 'target'
End
End
End
