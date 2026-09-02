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
  k3sProxy = pkgs.writeShellApplication {
    name = "openclaw-k3s-proxy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.iproute2
      pkgs.socat
    ];
    text = builtins.readFile ./k3s-proxy.sh;
  };
in
# Only enable on kyber (gateway host)
lib.mkIf host.isKyber {
  # Ensure OpenClaw directories exist with correct permissions
  home.activation.openclawSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${homeDir}"
  '';

  # Systemd service for OpenClaw gateway
  systemd.user.services.openclaw-gateway = {
    Unit = {
      Description = "OpenClaw gateway";
      After = [
        "network-online.target"
        "install-npm-globals.service"
      ];
      Wants = [ "network-online.target" ];
      X-SwitchMethod = "restart";
      StartLimitIntervalSec = 300;
      StartLimitBurst = 10;
    };
    Service = {
      Type = "simple";
      ExecStart = "${homeDir}/.bun/bin/openclaw gateway run --port 18789 --bind loopback";
      Restart = "always";
      RestartSec = "5s";
      EnvironmentFile = [ "-${homeDir}/dotfiles/.env" ];
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

  # Keep the gateway loopback-only while making it reachable from k3s. The
  # proxy binds exclusively to Kyber's CNI bridge, so port 18789 is not exposed
  # on the public or Tailscale interfaces.
  systemd.user.services.openclaw-k3s-proxy = {
    Unit = {
      Description = "OpenClaw k3s bridge proxy";
      After = [ "openclaw-gateway.service" ];
      Requires = [ "openclaw-gateway.service" ];
      X-SwitchMethod = "restart";
      StartLimitIntervalSec = 300;
      StartLimitBurst = 3;
    };
    Service = {
      Type = "simple";
      ExecStart = "${k3sProxy}/bin/openclaw-k3s-proxy";
      Restart = "on-failure";
      RestartSec = "30s";
      NoNewPrivileges = true;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
