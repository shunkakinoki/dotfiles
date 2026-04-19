{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) host;
  homeDir = config.home.homeDirectory;
in
# Only enable on kyber (server host)
lib.mkIf host.isKyber {
  # Ensure Paperclip directories exist with correct permissions
  home.activation.paperclipSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${homeDir}"
  '';

  # Systemd service for Paperclip
  systemd.user.services.paperclip = {
    Unit = {
      Description = "Paperclip AI agent orchestration platform";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -c 'exec env DATABASE_URL=\"$PAPERCLIP_DATABASE_URL\" BETTER_AUTH_BASE_URL=\"$PAPERCLIP_BETTER_AUTH_BASE_URL\" ${homeDir}/.bun/bin/paperclipai run --no-repair'";
      Restart = "always";
      RestartSec = "5s";
      Environment = [
        "HOME=${homeDir}"
        "HOST=0.0.0.0"
        "PAPERCLIP_DEPLOYMENT_MODE=authenticated"
        "PAPERCLIP_ALLOWED_HOSTNAMES=paperclip.shunkakinoki.com,172.17.0.1"
        "BETTER_AUTH_URL=https://paperclip.shunkakinoki.com"
        "BETTER_AUTH_BASE_URL=https://paperclip.shunkakinoki.com"
        "PATH=${homeDir}/.local/bin:${homeDir}/.bun/bin:${homeDir}/.nix-profile/bin:${homeDir}/.local/share/pnpm:${homeDir}/.local/share/fnm/current/bin:${homeDir}/.npm-global/bin:/usr/local/bin:/usr/bin:/bin"
      ];
      EnvironmentFile = [
        "${homeDir}/dotfiles/.env"
        "${homeDir}/.paperclip/instances/default/.env"
      ];
      WorkingDirectory = "${homeDir}/.paperclip";
      StandardOutput = "append:/tmp/paperclip/paperclip.log";
      StandardError = "append:/tmp/paperclip/paperclip.log";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
