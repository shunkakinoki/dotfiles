{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host) isKyber;
  homeDir = config.home.homeDirectory;
  roborevBin = "${homeDir}/.local/bin/roborev";
  dataDir = "${homeDir}/.roborev";
  serverAddr = "127.0.0.1:7373";
  enabled = isKyber;
in
lib.mkIf enabled {
  home.activation.roborevSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${dataDir}"
  '';

  launchd.agents.roborev = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./start.sh}"
        roborevBin
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
      ExecStart = "${pkgs.bash}/bin/bash ${./start.sh} ${roborevBin} ${serverAddr}";
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
