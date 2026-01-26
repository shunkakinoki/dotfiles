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
  # Ensure clawdbot directories exist
  # Note: Node symlink is managed by fnm module
  home.activation.clawdbotSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p /tmp/clawdbot
    mkdir -p ${homeDir}/.clawdbot
  '';

  # Systemd service for clawdbot gateway
  systemd.user.services.clawdbot-gateway = {
    Unit = {
      Description = "Clawdbot gateway";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${homeDir}/.bun/bin/clawdbot gateway --port 18789";
      Restart = "always";
      RestartSec = "5s";
      Environment = [
        "HOME=${homeDir}"
        "PATH=${homeDir}/.local/bin:${homeDir}/.bun/bin:${homeDir}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin"
      ];
      WorkingDirectory = "${homeDir}/.clawdbot";
      StandardOutput = "append:/tmp/clawdbot/clawdbot-gateway.log";
      StandardError = "append:/tmp/clawdbot/clawdbot-gateway.log";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
