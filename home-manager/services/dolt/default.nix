{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host) isKyber isGalactica;
  homeDir = config.home.homeDirectory;
  repoDir = "${homeDir}/dotfiles";
  beadsDir = "${repoDir}/.beads";
  enabled = isKyber || isGalactica;
  # 1.86+ adds the git+https:// remote scheme used by the beads_global GitHub backup.
  doltMinVersion = "1.86";
  startScript = pkgs.replaceVars ./start.sh {
    inherit beadsDir;
    inherit (pkgs) dolt;
  };
in
lib.mkIf enabled {
  assertions = [
    {
      assertion = lib.versionAtLeast pkgs.dolt.version doltMinVersion;
      message = "pkgs.dolt is ${pkgs.dolt.version}; needs >= ${doltMinVersion} for git+https push (beads_global GitHub backup). Run 'nix flake update nixpkgs-unstable'.";
    }
  ];

  home.sessionVariables = {
    BEADS_DOLT_SHARED_SERVER = "1";
    BEADS_DOLT_SERVER_PORT = "3307";
  };

  launchd.agents.dolt = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${startScript}"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      WorkingDirectory = repoDir;
      StandardOutPath = "/tmp/dolt.log";
      StandardErrorPath = "/tmp/dolt.error.log";
    };
  };

  systemd.user.services.dolt = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Dolt SQL server for dotfiles beads";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash ${startScript}";
      Restart = "always";
      RestartSec = 5;
      WorkingDirectory = repoDir;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
