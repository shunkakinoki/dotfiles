{ pkgs, ... }:
let
  inherit (pkgs) lib;
  startPostgresWrapper = pkgs.writeShellScript "start-postgres-wrapper" ''
    exec /usr/bin/sg docker -c "${pkgs.bash}/bin/bash ${./start-postgres.sh}"
  '';
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
      Restart = "on-failure";
      RestartSec = 30;
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.coreutils
          pkgs.docker
        ]
      }";
      ExecStart = "${startPostgresWrapper}";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
