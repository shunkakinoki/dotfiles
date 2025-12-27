{ pkgs, ... }:
let
  inherit (pkgs) lib;

  # Create start script with paths substituted at build time
  startScript = pkgs.replaceVars ./scripts/start.sh {
    aws = "${pkgs.awscli2}/bin/aws";
    sed = "${pkgs.gnused}/bin/sed";
  };

  # Create backup scripts with paths substituted at build time
  backupAuthScript = pkgs.replaceVars ./scripts/backup-auth.sh {
    aws = "${pkgs.awscli2}/bin/aws";
    rsync = "${pkgs.rsync}/bin/rsync";
  };
  recoverAuthScript = pkgs.replaceVars ./scripts/recover-auth.sh {
    aws = "${pkgs.awscli2}/bin/aws";
  };
  backupAndRecoverScript = pkgs.replaceVars ./scripts/backup-and-recover.sh {
    backupAuthScript = backupAuthScript;
    recoverAuthScript = recoverAuthScript;
  };
in
{
  # Main cliproxyapi service
  launchd.agents.cliproxyapi = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${startScript}"
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
      ExecStart = "${pkgs.bash}/bin/bash ${startScript}";
      Restart = "always";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Backup/recovery service with file watching for real-time sync
  launchd.agents.cliproxyapi-backup = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${backupAndRecoverScript}"
      ];
      Environment = {
        HOME = "/Users/shunkakinoki";
        PATH = "${
          lib.makeBinPath [
            pkgs.bash
            pkgs.coreutils
            pkgs.awscli2
            pkgs.rsync
          ]
        }:/opt/homebrew/bin:/usr/local/bin:/usr/bin";
      };
      # Watch auth directories for changes - triggers sync immediately
      WatchPaths = [
        "/Users/shunkakinoki/.cli-proxy-api/objectstore/auths"
        "/Users/shunkakinoki/dotfiles/objectstore/auths"
        "/Users/shunkakinoki/.ccs/cliproxy/auth"
      ];
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
      OnUnitActiveSec = "3min";
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
      ExecStart = "${pkgs.bash}/bin/bash ${backupAndRecoverScript}";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.awscli2
          pkgs.coreutils
        ]
      }";
    };
  };
}
