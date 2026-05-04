#!/usr/bin/env bash
# shellcheck disable=SC2329
# This test ensures every shell script in the repository has a corresponding spec file

Describe 'shell script test coverage'

Describe 'all required scripts have spec files'
It 'has spec file for config/claude/hooks/notify.sh'
The path "spec/notify_spec.sh" should be exist
End

It 'has spec file for config/claude/hooks/pushover.sh'
The path "spec/pushover_spec.sh" should be exist
End

It 'has spec file for config/claude/hooks/rtk-rewrite.sh'
The path "spec/rtk_rewrite_spec.sh" should be exist
End

It 'has spec file for config/claude/hooks/atuin-history.sh'
The path "spec/atuin_history_spec.sh" should be exist
End

It 'has spec file for config/claude/hooks/auto-switch.sh'
The path "spec/auto_switch_spec.sh" should be exist
End

It 'has spec file for config/claude/hooks/security.sh'
The path "spec/security_spec.sh" should be exist
End

It 'has spec file for config/claude/hooks/statusline.sh'
The path "spec/statusline_spec.sh" should be exist
End

It 'has spec file for config/claude/hooks/auto-switch.sh'
The path "spec/auto_switch_spec.sh" should be exist
End

It 'has spec file for config/hyprland/scripts/record-screen.sh'
The path "spec/hyprland_record_screen_spec.sh" should be exist
End

It 'has spec file for config/hyprland/scripts/toggle-terminal.sh'
The path "spec/hyprland_toggle_terminal_spec.sh" should be exist
End

It 'has spec file for home-manager/programs/neovim/run_tests.sh'
The path "spec/neovim_tests_spec.sh" should be exist
End

It 'has spec file for home-manager/services/cass/daily.sh'
The path "spec/cass_indexer_spec.sh" should be exist
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

It 'has spec file for home-manager/services/cliproxyapi/scripts/common.sh'
The path "spec/cliproxyapi_backup_spec.sh" should be exist
End

It 'has spec file for home-manager/services/cliproxyapi/scripts/keychain-sync.sh'
The path "spec/cliproxyapi_keychain_sync_spec.sh" should be exist
End

It 'has spec file for home-manager/services/code-syncer/sync.sh'
The path "spec/code_syncer_spec.sh" should be exist
End

It 'has spec file for home-manager/services/docker-postgres/start-postgres.sh'
The path "spec/docker_postgres_spec.sh" should be exist
End

It 'has spec file for home-manager/services/docker-postgres/start-postgres-wrapper.sh'
The path "spec/start_postgres_wrapper_spec.sh" should be exist
End

It 'has spec file for home-manager/services/dotfiles-updater/update.sh'
The path "spec/dotfiles_updater_spec.sh" should be exist
End

It 'has spec file for home-manager/services/gas-town/start.sh'
The path "spec/gas_town_spec.sh" should be exist
End

It 'has spec file for home-manager/services/make-updater/update.sh'
The path "spec/make_updater_spec.sh" should be exist
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

It 'has spec file for scripts/update-local-binaries.sh'
The path "spec/update_local_binaries_spec.sh" should be exist
End

It 'has spec file for scripts/upgrade-overlays.sh'
The path "spec/upgrade_overlays_spec.sh" should be exist
End

It 'has spec file for scripts/wallpaper-power-check.sh'
The path "spec/wallpaper_power_check_spec.sh" should be exist
End

It 'has spec file for home-manager/modules/local-binaries/sync-local-binaries.sh'
The path "spec/local_binaries_spec.sh" should be exist
End

It 'has spec file for home-manager/modules/cargo-globals/install-cargo-globals.sh'
The path "spec/cargo_globals_spec.sh" should be exist
End

It 'has spec file for config/hermes/hydrate.sh'
The path "spec/hermes_hydrate_spec.sh" should be exist
End

It 'has spec file for config/openclaw/hydrate.sh'
The path "spec/openclaw_hydrate_spec.sh" should be exist
End

It 'has spec file for config/paperclip/hydrate.sh'
The path "spec/paperclip_hydrate_spec.sh" should be exist
End

It 'has spec file for home-manager/modules/npm-globals/install-npm-globals.sh'
The path "spec/npm_globals_spec.sh" should be exist
End

It 'has spec file for home-manager/modules/secure-dotenv/secure-dotenv.sh'
The path "spec/secure_dotenv_spec.sh" should be exist
End

It 'has spec file for home-manager/modules/uv-globals/install-uv-globals.sh'
The path "spec/uv_globals_spec.sh" should be exist
End

It 'has spec file for named-hosts/matic/falcon-init.sh'
The path "spec/falcon_init_spec.sh" should be exist
End

It 'has spec file for named-hosts/matic/pam-gnome-keyring-tpm-unlock.sh'
The path "spec/pam_gnome_keyring_tpm_unlock_spec.sh" should be exist
End

It 'has spec file for scripts/fishtape-wrapper.sh'
The path "spec/fishtape_wrapper_spec.sh" should be exist
End

It 'has spec file for scripts/check-nix-inline-scripts.sh'
The path "spec/check_nix_inline_scripts_spec.sh" should be exist
End

It 'has spec file for scripts/find-built-iso.sh'
The path "spec/find_built_iso_spec.sh" should be exist
End

It 'has spec file for home-manager/services/cliproxyapi/scripts/docker-start.sh'
The path "spec/cliproxyapi_docker_start_spec.sh" should be exist
End

It 'has spec file for home-manager/services/docker/setup-docker.sh'
The path "spec/docker_setup_spec.sh" should be exist
End

It 'has spec file for home-manager/services/docker/docker-setup.sh'
The path "spec/docker_setup_wrapper_spec.sh" should be exist
End

It 'has spec file for home-manager/services/dolt/start.sh'
The path "spec/dolt_start_spec.sh" should be exist
End

It 'has spec file for home-manager/services/k3s/activate.sh'
The path "spec/k3s_service_activate_spec.sh" should be exist
End
It 'has spec file for nix-darwin/services/pmset-battery-policy/power-policy.sh'
The path "spec/pmset_battery_policy_spec.sh" should be exist
End

It 'has spec file for home-manager/activation/ensure-directory.sh'
The path "spec/activation_shared_spec.sh" should be exist
End

It 'has spec file for home-manager/activation/deploy-agenix-secret.sh'
The path "spec/activation_shared_spec.sh" should be exist
End

It 'has spec file for home-manager/activation/import-gpg-key.sh'
The path "spec/activation_shared_spec.sh" should be exist
End

It 'has spec file for config/codex/activate.sh'
The path "spec/activate_config_spec.sh" should be exist
End

It 'has spec file for config/claude/activate.sh'
The path "spec/activate_config_spec.sh" should be exist
End

It 'has spec file for config/cursor/activate.sh'
The path "spec/activate_config_spec.sh" should be exist
End

It 'has spec file for config/omp/activate.sh'
The path "spec/activate_config_spec.sh" should be exist
End

It 'has spec file for config/gemini/activate.sh'
The path "spec/activate_config_spec.sh" should be exist
End

It 'has spec file for config/git-ai/activate.sh'
The path "spec/activate_config_spec.sh" should be exist
End

It 'has spec file for config/obsidian/activate.sh'
The path "spec/activate_config_spec.sh" should be exist
End

It 'has spec file for config/serena/activate.sh'
The path "spec/activate_config_spec.sh" should be exist
End

It 'has spec file for config/k3s/activate.sh'
The path "spec/activate_k3s_spec.sh" should be exist
End

It 'has spec file for hosts/darwin/activate-remove-backups.sh'
The path "spec/activate_hosts_spec.sh" should be exist
End

It 'has spec file for hosts/linux/activate-backup-files.sh'
The path "spec/activate_hosts_spec.sh" should be exist
End

It 'has spec file for named-hosts/kyber/activate-backup-files.sh'
The path "spec/activate_kyber_spec.sh" should be exist
End

It 'has spec file for named-hosts/kyber/activate-ip-forwarding.sh'
The path "spec/activate_kyber_spec.sh" should be exist
End

It 'has spec file for home-manager/modules/bin-shells/activate.sh'
The path "spec/activate_bin_shells_spec.sh" should be exist
End

It 'has spec file for home-manager/modules/paperclip/activate.sh'
The path "spec/activate_paperclip_openclaw_spec.sh" should be exist
End

It 'has spec file for home-manager/services/hermes/activate.sh'
The path "spec/activate_paperclip_openclaw_spec.sh" should be exist
End

It 'has spec file for home-manager/modules/openclaw/activate.sh'
The path "spec/activate_paperclip_openclaw_spec.sh" should be exist
End

It 'has spec file for home-manager/modules/tailscale/activate-create-dirs.sh'
The path "spec/activate_tailscale_spec.sh" should be exist
End

It 'has spec file for home-manager/modules/tailscale/activate-install-service.sh'
The path "spec/activate_tailscale_spec.sh" should be exist
End

It 'has spec file for home-manager/programs/fnm/activate.sh'
The path "spec/activate_fnm_spec.sh" should be exist
End

It 'has spec file for home-manager/programs/neovim/activate-copy-pack-lock.sh'
The path "spec/activate_neovim_spec.sh" should be exist
End

It 'has spec file for home-manager/programs/neovim/activate-build-plugins.sh'
The path "spec/activate_neovim_spec.sh" should be exist
End

End

Describe 'fish shortcut declarations'
FISH_SCRIPT="$PWD/home-manager/programs/fish/default.nix"

It 'defines ompc abbreviation'
When run grep -F 'ompc = "omp commit";' "$FISH_SCRIPT"
The status should be success
The output should include 'ompc = "omp commit";'
End

It 'defines ompcp abbreviation'
When run grep -F 'ompcp = "omp commit --push";' "$FISH_SCRIPT"
The status should be success
The output should include 'ompcp = "omp commit --push";'
End

It 'registers ompxe helper abbreviation'
When run grep -F 'ompxe = "_ompxe_function";' "$FISH_SCRIPT"
The status should be success
The output should include 'ompxe = "_ompxe_function";'
End

It 'registers ompxeh helper abbreviation'
When run grep -F 'ompxeh = "_ompxeh_function";' "$FISH_SCRIPT"
The status should be success
The output should include 'ompxeh = "_ompxeh_function";'
End
End

Describe 'no shell scripts are missing from coverage list'
# This test will fail if a new .sh file is added without updating this spec
# When adding a new shell script, add it to this list AND create a corresponding spec file

It 'covers all non-spec shell scripts in the repository'
# List of all shell scripts that should have tests
# Update this list when adding new shell scripts
covered_scripts="config/claude/activate.sh
config/ccs/hydrate.sh
config/claude/hooks/notify.sh
config/claude/hooks/pushover.sh
config/claude/hooks/rtk-rewrite.sh
config/claude/hooks/auto-switch.sh
config/claude/hooks/security.sh
config/claude/hooks/atuin-history.sh
config/claude/hooks/statusline.sh
config/codex/activate.sh
config/codex/hooks/atuin-history.sh
config/codex/hooks/notify.sh
config/codex/hooks/pushover.sh
config/codex/hooks/rtk-rewrite.sh
config/codex/hooks/security.sh
config/shared/hooks/block-gh-settings.sh
config/shared/hooks/block-git-push.sh
config/cursor/activate.sh
config/gemini/activate.sh
config/git-ai/activate.sh
config/hermes/hydrate.sh
config/hyprland/scripts/record-screen.sh
config/hyprland/scripts/toggle-terminal.sh
config/k3s/activate.sh
config/noctalia/ac-idle-inhibit.sh
config/obsidian/activate.sh
config/omp/activate.sh
config/openclaw/hydrate.sh
config/paperclip/hydrate.sh
config/serena/activate.sh
home-manager/activation/deploy-agenix-secret.sh
home-manager/activation/ensure-directory.sh
home-manager/activation/import-gpg-key.sh
home-manager/modules/bin-shells/activate.sh
home-manager/modules/cargo-globals/install-cargo-globals.sh
home-manager/modules/local-binaries/sync-local-binaries.sh
home-manager/modules/local-scripts/clipboard-copy.sh
home-manager/modules/local-scripts/clipboard-paste.sh
home-manager/modules/local-scripts/decafinate.sh
home-manager/modules/local-scripts/notify-local.sh
home-manager/modules/local-scripts/pushover-notify.sh
home-manager/modules/local-scripts/tmux-bridge.sh
home-manager/modules/npm-globals/install-npm-globals.sh
home-manager/modules/secure-dotenv/secure-dotenv.sh
home-manager/services/hermes/activate.sh
home-manager/services/obsidian/obsidian-git-trigger.sh
home-manager/services/obsidian/obsidian-headless.sh
home-manager/services/openclaw/activate.sh
home-manager/services/paperclip/activate.sh
home-manager/services/qmd/activate.sh
home-manager/modules/tailscale/activate-create-dirs.sh
home-manager/modules/tailscale/activate-install-service.sh
home-manager/modules/uv-globals/install-uv-globals.sh
home-manager/programs/fnm/activate.sh
home-manager/programs/neovim/activate-build-plugins.sh
home-manager/programs/neovim/activate-copy-pack-lock.sh
home-manager/programs/neovim/run_tests.sh
home-manager/programs/tmux/session-logger.sh
home-manager/services/brew-upgrader/upgrade.sh
home-manager/services/cass/daily.sh
home-manager/services/cliproxyapi/scripts/backup.sh
home-manager/services/cliproxyapi/scripts/common.sh
home-manager/services/cliproxyapi/scripts/docker-start.sh
home-manager/services/cliproxyapi/scripts/hydrate.sh
home-manager/services/cliproxyapi/scripts/keychain-sync.sh
home-manager/services/cliproxyapi/scripts/start.sh
home-manager/services/cliproxyapi/scripts/wrapper.sh
home-manager/services/code-syncer/sync.sh
home-manager/services/docker-postgres/start-postgres-wrapper.sh
home-manager/services/docker-postgres/start-postgres.sh
home-manager/services/docker/docker-setup.sh
home-manager/services/docker/setup-docker.sh
home-manager/services/dolt/start.sh
home-manager/services/dotfiles-updater/update.sh
home-manager/services/gas-town/start.sh
home-manager/services/k3s/activate.sh
home-manager/services/make-updater/update.sh
home-manager/services/neverssl-keepalive/keepalive.sh
hosts/darwin/activate-remove-backups.sh
hosts/linux/activate-backup-files.sh
install.sh
named-hosts/kyber/activate-backup-files.sh
named-hosts/kyber/activate-ip-forwarding.sh
named-hosts/kyber/rekey-galactica.sh
named-hosts/kyber/setup.sh
named-hosts/matic/falcon-init.sh
named-hosts/matic/pam-gnome-keyring-tpm-unlock.sh
nix-darwin/services/pmset-battery-policy/power-policy.sh
scripts/build-neovim-plugins.sh
scripts/check-nix-inline-scripts.sh
scripts/find-built-iso.sh
scripts/fishtape-wrapper.sh
scripts/llm-update.sh
scripts/sync-codex-security.sh
scripts/sync-rtk-rewrite.sh
scripts/update-gitalias.sh
scripts/update-local-binaries.sh
scripts/upgrade-overlays.sh
scripts/wallpaper-power-check.sh"

# Get actual scripts from git (excluding spec directory)
actual_scripts=$(git ls-files '*.sh' 2>/dev/null | grep -v '^spec/' | sort)
expected_scripts=$(echo "$covered_scripts" | sort)

When run bash -c "diff <(echo '$actual_scripts') <(echo '$expected_scripts') || echo 'MISMATCH: Update coverage_spec.sh when adding new shell scripts'"
The output should eq ''
End
End

End
