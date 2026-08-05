{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host) isGalactica isKyber isMatic;
  homeDir = config.home.homeDirectory;
  roborevBin = "${homeDir}/.local/bin/roborev";
  dataDir = "${homeDir}/.roborev";
  serverAddr = "127.0.0.1:7373";
  enabled = isGalactica || isKyber || isMatic;
in
lib.mkIf enabled {
  home.activation.roborevSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${dataDir}"
  '';

  launchd.agents.roborev = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        roborevBin
        "daemon"
        "run"
        "--addr"
        serverAddr
      ];
      KeepAlive = true;
      RunAtLoad = true;
      EnvironmentVariables = {
        HOME = homeDir;
        ROBOREV_DATA_DIR = dataDir;
        PATH = "${homeDir}/.local/bin:/etc/profiles/per-user/${config.home.username}/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
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
      ExecStart = "${roborevBin} daemon run --addr ${serverAddr}";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "HOME=${homeDir}"
        "ROBOREV_DATA_DIR=${dataDir}"
        "PATH=${homeDir}/.local/bin:/etc/profiles/per-user/${config.home.username}/bin:${homeDir}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin"
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
