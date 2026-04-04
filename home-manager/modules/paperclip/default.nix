{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (inputs) host;
  homeDir = config.home.homeDirectory;
  repoDir = "${homeDir}/ghq/github.com/paperclipai/paperclip";
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
  # Runs from cloned repo via pnpm dev:once — the global bun install has a
  # pino-http/pino version mismatch that crashes node after the first request.
  # The repo's lockfile resolves deps correctly.
  systemd.user.services.paperclip = {
    Unit = {
      Description = "Paperclip AI agent orchestration platform";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${homeDir}/.bun/bin/pnpm dev:once";
      Restart = "always";
      RestartSec = "5s";
      Environment = [
        "HOME=${homeDir}"
        "HOST=0.0.0.0"
        "PAPERCLIP_DEPLOYMENT_MODE=authenticated"
        "PAPERCLIP_ALLOWED_HOSTNAMES=paperclip.shunkakinoki.com,172.17.0.1"
        "PATH=${homeDir}/.local/bin:${homeDir}/.bun/bin:${homeDir}/.nix-profile/bin:${homeDir}/.local/share/pnpm:${homeDir}/.local/share/fnm/current/bin:${homeDir}/.npm-global/bin:/usr/local/bin:/usr/bin:/bin"
      ];
      EnvironmentFile = [
        "${homeDir}/dotfiles/.env"
        "${homeDir}/.paperclip/instances/default/.env"
      ];
      WorkingDirectory = "${repoDir}";
      StandardOutput = "append:/tmp/paperclip/paperclip.log";
      StandardError = "append:/tmp/paperclip/paperclip.log";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
