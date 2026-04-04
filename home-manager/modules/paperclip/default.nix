{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (inputs) host;
  homeDir = config.home.homeDirectory;
  instanceDir = "${homeDir}/.paperclip/instances/default";
in
# Only enable on kyber (server host)
lib.mkIf host.isKyber {
  # Ensure Paperclip directories exist with correct permissions
  home.activation.paperclipSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p /tmp/paperclip
    mkdir -p ${homeDir}/.paperclip
    chmod 700 ${homeDir}/.paperclip
  '';

  # Systemd service for Paperclip
  systemd.user.services.paperclip = {
    Unit = {
      Description = "Paperclip AI agent orchestration platform";
      After = [
        "network-online.target"
        "docker-postgres.service"
      ];
      Wants = [ "network-online.target" ];
      Requires = [ "docker-postgres.service" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${homeDir}/.bun/bin/paperclipai run";
      Restart = "always";
      RestartSec = "5s";
      Environment = [
        "HOME=${homeDir}"
        "PATH=${homeDir}/.local/bin:${homeDir}/.bun/bin:${homeDir}/.nix-profile/bin:${homeDir}/.local/share/pnpm:${homeDir}/.local/share/fnm/current/bin:${homeDir}/.npm-global/bin:/usr/local/bin:/usr/bin:/bin"
      ];
      EnvironmentFile = "${instanceDir}/.env";
      WorkingDirectory = "${homeDir}/.paperclip";
      StandardOutput = "append:/tmp/paperclip/paperclip.log";
      StandardError = "append:/tmp/paperclip/paperclip.log";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
