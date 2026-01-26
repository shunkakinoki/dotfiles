{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  inherit (inputs) env host;
  homeDir = config.home.homeDirectory;
  fnmNodePath = "${homeDir}/.local/share/fnm/node-versions/v22.22.0/installation/bin/node";
in
# Only enable on kyber (gateway host)
lib.mkIf (host.isKyber) {
  # Create node symlink for clawdbot (requires Node >=22)
  home.file.".local/bin/node" = {
    source = config.lib.file.mkOutOfStoreSymlink fnmNodePath;
  };

  # Ensure clawdbot directories exist
  home.activation.clawdbotSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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
        "PATH=${homeDir}/.bun/bin:${homeDir}/.nix-profile/bin:${homeDir}/.local/bin:/usr/local/bin:/usr/bin:/bin"
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
