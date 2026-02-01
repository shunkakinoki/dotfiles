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
lib.mkIf (host.isKyber) {
  # Ensure OpenClaw directories exist
  # Note: Node symlink is managed by fnm module
  home.activation.openclawSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p /tmp/openclaw
    mkdir -p ${homeDir}/.openclaw
  '';

  # Systemd service for OpenClaw gateway
  systemd.user.services.openclaw-gateway = {
    Unit = {
      Description = "OpenClaw gateway";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${homeDir}/.bun/bin/openclaw gateway --port 18789";
      Restart = "always";
      RestartSec = "5s";
      Environment = [
        "HOME=${homeDir}"
        "PATH=${homeDir}/.local/bin:${homeDir}/.bun/bin:${homeDir}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin"
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
