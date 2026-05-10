{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host) isGalactica isMatic;
  homeDir = config.home.homeDirectory;
  roborevBin = "${homeDir}/.local/bin/roborev";
  dataDir = "${homeDir}/.roborev";
  enabled = isGalactica || isMatic;
in
lib.mkIf enabled {
  home.activation.roborevSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${dataDir}"
  '';

  launchd.agents.roborev = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        roborevBin
        "daemon"
        "run"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      EnvironmentVariables = {
        HOME = homeDir;
        ROBOREV_DATA_DIR = dataDir;
        PATH = "${homeDir}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
      };
      StandardOutPath = "/tmp/roborev.log";
      StandardErrorPath = "/tmp/roborev.error.log";
    };
  };

  systemd.user.services.roborev = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "roborev code review daemon";
      Documentation = [ "https://github.com/roborev-dev/roborev" ];
      After = [ "network.target" ];
    };
    Service = {
      Type = "notify";
      ExecStart = "${roborevBin} daemon run";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "HOME=${homeDir}"
        "ROBOREV_DATA_DIR=${dataDir}"
        "PATH=${homeDir}/.local/bin:${homeDir}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin"
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
