{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  desktopSettingsAgentLabel = "org.nix-community.home.codex-desktop-settings-sync";
  syncDesktopSettings = ./sync-desktop-settings.sh;
  ensureDesktopSettingsAgent = ./ensure-desktop-settings-agent.sh;
in
{
  # Use activation script instead of home.file symlink
  # Codex CLI uses atomic writes that break symlinks, so we force-copy on each switch
  home.activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" \
      "${./config.toml}" \
      "${./hooks.json}" \
      "${./desktop-settings.json}" \
      "${pkgs.jq}/bin/jq" \
      "${syncDesktopSettings}"
  '';

  # Codex caches Desktop preferences in memory and replaces its complete state
  # file after activation. Restore managed keys after each app-owned rewrite;
  # the synchronizer exits without writing once the values already match.
  launchd.agents.codex-desktop-settings-sync = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${syncDesktopSettings}"
        "${./desktop-settings.json}"
        "${pkgs.jq}/bin/jq"
      ];
      WatchPaths = [ "${homeDir}/.codex/.codex-global-state.json" ];
      ThrottleInterval = 2;
      RunAtLoad = true;
      KeepAlive = false;
      StandardOutPath = "/tmp/codex-desktop-settings-sync.log";
      StandardErrorPath = "/tmp/codex-desktop-settings-sync.error.log";
    };
  };

  # Home Manager normally installs and bootstraps launchd.agents during
  # setupLaunchAgents. Self-heal after that phase so a missed registration
  # cannot leave the app free to replace the managed settings permanently.
  home.activation.codexDesktopSettingsAgent = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "setupLaunchAgents" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${ensureDesktopSettingsAgent}" \
        "${desktopSettingsAgentLabel}" \
        "$newGenPath/LaunchAgents/${desktopSettingsAgentLabel}.plist" \
        "/bin/launchctl" \
        "${pkgs.coreutils}/bin/install" \
        "${pkgs.coreutils}/bin/id"
    ''
  );

  home.file.".codex/hooks/notify.sh" = {
    source = ./hooks/notify.sh;
    executable = true;
    force = true;
  };

  home.file.".codex/hooks/pushover.sh" = {
    source = ./hooks/pushover.sh;
    executable = true;
    force = true;
  };

  home.file.".codex/hooks/atuin-history.sh" = {
    source = ./hooks/atuin-history.sh;
    executable = true;
    force = true;
  };
}
