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
lib.mkIf host.isKyber {
  home.activation.hermesSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${homeDir}"
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
        "PATH=${homeDir}/.local/bin:${homeDir}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin"
      ];
      WorkingDirectory = "${homeDir}/.hermes";
      StandardOutput = "append:/tmp/hermes/hermes-gateway.log";
      StandardError = "append:/tmp/hermes/hermes-gateway.log";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
