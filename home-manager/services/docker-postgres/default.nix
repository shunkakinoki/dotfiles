{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host) isGalactica isMatic;
  enabled = isGalactica || isMatic;
  startScript = ./start-postgres.sh;

  # Smart wrapper that handles both NixOS and non-NixOS Linux
  # On NixOS: docker group is properly inherited, or use /run/wrappers/bin/sg
  # On non-NixOS: systemd user session may lack docker group, use /usr/bin/sg
  startPostgresWrapper = pkgs.writeShellScript "start-postgres-wrapper" (
    builtins.readFile (
      pkgs.replaceVars ./start-postgres-wrapper.sh {
        inherit (pkgs) bash;
        start_script = startScript;
        inherit (pkgs) docker;
      }
    )
  );
in
lib.mkIf enabled {
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
