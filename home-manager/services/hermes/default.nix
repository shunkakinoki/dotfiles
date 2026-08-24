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
  hermesNode = pkgs.nodejs_22;
in
lib.mkIf host.isKyber {
  # Clean up writable copies that Hermes activate.sh creates (replacing Nix-managed
  # symlinks) so they don't block the next nix-switch's linkGeneration.
  home.activation.hermesCleanup = config.lib.dag.entryBefore [ "checkLinkTargets" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-cleanup-units.sh}" \
      "${homeDir}/.config/systemd/user" \
      hermes-gateway.service \
      hermes-dashboard.service \
      hermes-dashboard-proxy.service
  '';

  home.activation.hermesSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${homeDir}" "${hermesNode}/bin/npm"
  '';

  systemd.user.services.hermes-gateway = {
    Unit = {
      Description = "Hermes gateway";
      After = [
        "network-online.target"
      ];
      Wants = [ "network-online.target" ];
      StartLimitIntervalSec = 300;
      StartLimitBurst = 10;
    };
    Service = {
      Type = "simple";
      ExecStart = "${homeDir}/.local/bin/hermes gateway";
      Restart = "always";
      RestartSec = "5s";
      Environment = [
        "HOME=${homeDir}"
        "PATH=${hermesNode}/bin:${homeDir}/.local/bin:${homeDir}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin"
        "NPM_CONFIG_INCLUDE=optional"
        "NPM_CONFIG_IGNORE_SCRIPTS=false"
      ];
      RuntimeDirectory = "hermes";
      RuntimeDirectoryMode = "0700";
      RuntimeDirectoryPreserve = "yes";
      WorkingDirectory = "${homeDir}/.hermes";
      StandardOutput = "append:%t/hermes/hermes-gateway.log";
      StandardError = "append:%t/hermes/hermes-gateway.log";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.hermes-dashboard = {
    Unit = {
      Description = "Hermes dashboard";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      StartLimitIntervalSec = 300;
      StartLimitBurst = 10;
    };
    Service = {
      Type = "simple";
      ExecStart = "${homeDir}/.local/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open --skip-build";
      Restart = "always";
      RestartSec = "5s";
      X-SwitchMethod = "restart";
      Environment = [
        "HOME=${homeDir}"
        "PATH=${hermesNode}/bin:${homeDir}/.local/bin:${homeDir}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin"
        "NPM_CONFIG_INCLUDE=optional"
        "NPM_CONFIG_IGNORE_SCRIPTS=false"
      ];
      RuntimeDirectory = "hermes";
      RuntimeDirectoryMode = "0700";
      RuntimeDirectoryPreserve = "yes";
      WorkingDirectory = "${homeDir}/.hermes";
      StandardOutput = "append:%t/hermes/hermes-dashboard.log";
      StandardError = "append:%t/hermes/hermes-dashboard.log";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.hermes-dashboard-proxy = {
    Unit = {
      Description = "Hermes dashboard Kubernetes bridge proxy";
      After = [ "hermes-dashboard.service" ];
      Requires = [ "hermes-dashboard.service" ];
    };
    Service = {
      Type = "simple";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /tmp/hermes-dashboard-proxy";
      ExecStart = "${pkgs.nginx}/bin/nginx -c ${./hermes-dashboard-proxy.conf} -p /tmp/hermes-dashboard-proxy -g 'daemon off;'";
      ExecStop = "${pkgs.nginx}/bin/nginx -c ${./hermes-dashboard-proxy.conf} -p /tmp/hermes-dashboard-proxy -s quit";
      Restart = "always";
      RestartSec = "5s";
      X-SwitchMethod = "restart";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
