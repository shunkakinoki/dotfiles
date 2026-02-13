{ pkgs, ... }:
let
  inherit (pkgs) lib;
  startScript = ./start-postgres.sh;

  # Smart wrapper that handles both NixOS and non-NixOS Linux
  # On NixOS: docker group is properly inherited, or use /run/wrappers/bin/sg
  # On non-NixOS: systemd user session may lack docker group, use /usr/bin/sg
  startPostgresWrapper = pkgs.writeShellScript "start-postgres-wrapper" ''
    SCRIPT="${pkgs.bash}/bin/bash ${startScript}"

    # Try docker directly first (works on NixOS or when user has docker group)
    if ${pkgs.docker}/bin/docker info >/dev/null 2>&1; then
      exec $SCRIPT
    fi

    # Docker not accessible directly, try sg to switch group
    # NixOS: /run/wrappers/bin/sg (SUID wrapper)
    # Non-NixOS: /usr/bin/sg (system binary with SUID)
    if [ -x /run/wrappers/bin/sg ]; then
      exec /run/wrappers/bin/sg docker -c "$SCRIPT"
    elif [ -x /usr/bin/sg ]; then
      exec /usr/bin/sg docker -c "$SCRIPT"
    else
      echo "ERROR: Cannot access Docker. User not in docker group and no sg binary found." >&2
      exit 1
    fi
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
