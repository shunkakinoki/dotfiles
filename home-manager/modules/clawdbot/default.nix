{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (inputs) env host;
  homeDir = config.home.homeDirectory;
in
# Only enable on kyber (gateway host)
lib.mkIf (host.isKyber) {
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
