{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (inputs) host;
  homeDir = config.home.homeDirectory;
in
# Only enable on kyber (gateway host)
lib.mkIf host.isKyber {
  # Ensure OpenClaw directories exist with correct permissions
  home.activation.openclawSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p /tmp/openclaw
    mkdir -p ${homeDir}/.openclaw
    chmod 700 ${homeDir}/.openclaw
  '';

  # Systemd service for OpenClaw gateway
  systemd.user.services.openclaw-gateway = {
    Unit = {
      Description = "OpenClaw gateway";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${homeDir}/.bun/bin/openclaw gateway --port 18789";
      Restart = "always";
      RestartSec = "5s";
      Environment = [
        "HOME=${homeDir}"
        "PATH=${homeDir}/.local/bin:${homeDir}/.bun/bin:${homeDir}/.nix-profile/bin:${homeDir}/.local/share/pnpm:${homeDir}/.local/share/fnm/current/bin:${homeDir}/.npm-global/bin:/usr/local/bin:/usr/bin:/bin"
      ];
      WorkingDirectory = "${homeDir}/.openclaw";
      StandardOutput = "append:/tmp/openclaw/openclaw-gateway.log";
      StandardError = "append:/tmp/openclaw/openclaw-gateway.log";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
