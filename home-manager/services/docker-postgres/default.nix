{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  launchd.agents.docker-postgres = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./start-postgres.sh}"
      ];
      EnvironmentVariables = {
        PATH = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin";
      };
      RunAtLoad = true;
      StandardOutPath = "/tmp/docker-postgres.log";
      StandardErrorPath = "/tmp/docker-postgres.error.log";
    };
  };

  systemd.user.services.docker-postgres = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "PostgreSQL Docker container auto-start";
      After = [
        "network.target"
        "docker.service"
      ];
      Wants = [ "docker.service" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.coreutils
          pkgs.docker
        ]
      }";
      ExecStart = "${pkgs.bash}/bin/bash ${./start-postgres.sh}";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
