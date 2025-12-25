#!/usr/bin/env bash
# shellcheck disable=SC2329
# This test ensures every shell script in the repository has a corresponding spec file

Describe 'shell script test coverage'

Describe 'all required scripts have spec files'
It 'has spec file for config/claude/notify.sh'
The path "spec/notify_spec.sh" should be exist
End

It 'has spec file for config/claude/pushover.sh'
The path "spec/pushover_spec.sh" should be exist
End

It 'has spec file for config/claude/security.sh'
The path "spec/security_spec.sh" should be exist
End

It 'has spec file for config/claude/statusline-git.sh'
The path "spec/statusline_git_spec.sh" should be exist
End

It 'has spec file for home-manager/programs/neovim/run_tests.sh'
The path "spec/neovim_tests_spec.sh" should be exist
End

It 'has spec file for home-manager/services/brew-upgrader/upgrade.sh'
The path "spec/brew_upgrader_spec.sh" should be exist
End

It 'has spec file for home-manager/services/cliproxyapi/scripts/start.sh'
The path "spec/cliproxyapi_spec.sh" should be exist
End

It 'has spec file for home-manager/services/cliproxyapi/scripts/backup-and-recover.sh'
The path "spec/cliproxyapi_backup_spec.sh" should be exist
End

It 'has spec file for home-manager/services/cliproxyapi/scripts/backup-auth.sh'
The path "spec/cliproxyapi_backup_spec.sh" should be exist
End

It 'has spec file for home-manager/services/cliproxyapi/scripts/recover-auth.sh'
The path "spec/cliproxyapi_backup_spec.sh" should be exist
End

It 'has spec file for home-manager/services/code-syncer/sync.sh'
The path "spec/code_syncer_spec.sh" should be exist
End

It 'has spec file for home-manager/services/dotfiles-updater/update.sh'
The path "spec/dotfiles_updater_spec.sh" should be exist
End

It 'has spec file for home-manager/services/neverssl-keepalive/keepalive.sh'
The path "spec/keepalive_spec.sh" should be exist
End

It 'has spec file for install.sh'
The path "spec/install_spec.sh" should be exist
End

It 'has spec file for named-hosts/kyber/rekey-galactica.sh'
The path "spec/kyber_rekey_spec.sh" should be exist
End

It 'has spec file for named-hosts/kyber/setup.sh'
The path "spec/kyber_setup_spec.sh" should be exist
End

It 'has spec file for scripts/update-gitalias.sh'
The path "spec/update_gitalias_spec.sh" should be exist
End
End

Describe 'no shell scripts are missing from coverage list'
# This test will fail if a new .sh file is added without updating this spec
# When adding a new shell script, add it to this list AND create a corresponding spec file

It 'covers all non-spec shell scripts in the repository'
# List of all shell scripts that should have tests
# Update this list when adding new shell scripts
covered_scripts="config/claude/notify.sh
config/claude/pushover.sh
config/claude/security.sh
config/claude/statusline-git.sh
home-manager/programs/neovim/run_tests.sh
home-manager/services/brew-upgrader/upgrade.sh
home-manager/services/cliproxyapi/scripts/backup-and-recover.sh
home-manager/services/cliproxyapi/scripts/backup-auth.sh
home-manager/services/cliproxyapi/scripts/recover-auth.sh
home-manager/services/cliproxyapi/scripts/start.sh
home-manager/services/code-syncer/sync.sh
home-manager/services/dotfiles-updater/update.sh
home-manager/services/neverssl-keepalive/keepalive.sh
install.sh
named-hosts/kyber/rekey-galactica.sh
named-hosts/kyber/setup.sh
scripts/update-gitalias.sh"

# Get actual scripts from git (excluding spec directory)
actual_scripts=$(git ls-files '*.sh' 2>/dev/null | grep -v '^spec/' | sort)
expected_scripts=$(echo "$covered_scripts" | sort)

When run bash -c "diff <(echo '$actual_scripts') <(echo '$expected_scripts') || echo 'MISMATCH: Update coverage_spec.sh when adding new shell scripts'"
The output should eq ''
End
End

End
