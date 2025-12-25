{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  # Main cliproxyapi service
  launchd.agents.cliproxyapi = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./scripts/start.sh}"
      ];
      Environment = {
        HOME = "/Users/shunkakinoki";
        PATH = "${
          lib.makeBinPath [
            pkgs.gnused
            pkgs.coreutils
            pkgs.awscli2
          ]
        }:/opt/homebrew/bin:/usr/local/bin:/usr/bin";
      };
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/cliproxyapi.log";
      StandardErrorPath = "/tmp/cliproxyapi.error.log";
    };
  };

  systemd.user.services.cliproxyapi = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "CLI Proxy API server";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.gnused
          pkgs.bash
          pkgs.coreutils
          pkgs.awscli2
        ]
      }";
      ExecStart = "${pkgs.bash}/bin/bash ${./scripts/start.sh}";
      Restart = "always";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Backup/recovery service
  launchd.agents.cliproxyapi-backup = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./scripts/backup-and-recover.sh}"
      ];
      StartInterval = 300; # Run every 5 minutes
      RunAtLoad = true;
      StandardOutPath = "/tmp/cliproxyapi-backup.log";
      StandardErrorPath = "/tmp/cliproxyapi-backup.error.log";
    };
  };

  systemd.user.timers.cliproxyapi-backup = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "CLIProxyAPI auth backup and recovery timer";
    };
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "cliproxyapi-backup.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  systemd.user.services.cliproxyapi-backup = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "CLIProxyAPI auth backup and recovery";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${./scripts/backup-and-recover.sh}";
    };
  };
}
