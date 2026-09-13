#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'hosts/darwin/activate-remove-backups.sh'
SCRIPT="$PWD/hosts/darwin/activate-remove-backups.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'removes hm-backup files from .codex'
When run bash -c "grep 'hm-backup' '$SCRIPT'"
The output should include 'hm-backup'
End

It 'uses find -delete'
When run bash -c "grep -- '-delete' '$SCRIPT'"
The output should include '-delete'
End

It 'suppresses errors gracefully'
When run bash -c "grep '|| true' '$SCRIPT'"
The output should include '|| true'
End
End

Describe 'hosts/linux/activate-backup-files.sh'
SCRIPT="$PWD/hosts/linux/activate-backup-files.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'backup behavior'
It 'backs up .bashrc'
When run bash -c "grep '.bashrc' '$SCRIPT'"
The output should include '.bashrc'
End

It 'backs up .profile'
When run bash -c "grep '.profile' '$SCRIPT'"
The output should include '.profile'
End

It 'backs up .bash_profile'
When run bash -c "grep '.bash_profile' '$SCRIPT'"
The output should include '.bash_profile'
End

It 'skips symlinks'
When run bash -c "grep -- '! -L' '$SCRIPT'"
The output should include '! -L'
End

It 'backs up openclaw config'
When run bash -c "grep 'openclaw' '$SCRIPT'"
The output should include 'openclaw.json'
End

It 'cleans up codex backups'
When run bash -c "grep 'codex' '$SCRIPT'"
The output should include 'hm-backup'
End

It 'removes stale Home Manager generation links'
When run bash -c "grep -F 'home-manager-generation' '$SCRIPT' >/dev/null && grep -F 'home-manager-files' '$SCRIPT' >/dev/null && grep -F 'rm -f --' '$SCRIPT' >/dev/null"
The status should be success
End

It 'uses the new generation manifest instead of scanning the home directory'
When run bash -c "grep -F 'home_files=' '$SCRIPT' >/dev/null && grep -F 'find -L \"\$home_files\"' '$SCRIPT' >/dev/null && grep -F '\"\$newGenPath/home-files\"' '$PWD/hosts/linux/default.nix' >/dev/null"
The status should be success
End
End

Describe 'managed file collisions'
setup() {
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/files/.config/atuin" "$TEMP_DIR/home/.config/atuin"
  printf 'managed\n' >"$TEMP_DIR/files/.config/atuin/config.toml"
  printf 'managed\n' >"$TEMP_DIR/files/.same"
}
cleanup() { rm -rf "$TEMP_DIR"; }
Before 'setup'
After 'cleanup'

It 'backs up an unmanaged file that differs from the managed one'
printf 'written by atuin\n' >"$TEMP_DIR/home/.config/atuin/config.toml"
When run bash -c 'HOME="$1/home" bash "$2" "$1/files" && [ ! -e "$1/home/.config/atuin/config.toml" ] && cat "$1/home/.config/atuin/config.toml.hm-backup"' _ "$TEMP_DIR" "$SCRIPT"
The output should include 'written by atuin'
End

It 'leaves an identical unmanaged file in place'
printf 'managed\n' >"$TEMP_DIR/home/.same"
When run bash -c 'HOME="$1/home" bash "$2" "$1/files" && [ -f "$1/home/.same" ] && [ ! -e "$1/home/.same.hm-backup" ]' _ "$TEMP_DIR" "$SCRIPT"
The status should be success
End
End
End
