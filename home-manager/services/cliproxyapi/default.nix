{ pkgs, ... }:
let
  inherit (pkgs) lib;

  # Create start script with paths substituted at build time
  startScript = pkgs.replaceVars ./scripts/start.sh {
    aws = "${pkgs.awscli2}/bin/aws";
    sed = "${pkgs.gnused}/bin/sed";
  };

  # Bundle all backup scripts together
  backupScripts = pkgs.runCommand "backup-scripts" { } ''
    mkdir -p $out
    cp ${./scripts/backup-and-recover.sh} $out/backup-and-recover.sh
    cp ${./scripts/backup-auth.sh} $out/backup-auth.sh
    cp ${./scripts/recover-auth.sh} $out/recover-auth.sh
    chmod +x $out/*.sh
  '';
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

  # Backup/recovery service
  launchd.agents.cliproxyapi-backup = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${backupScripts}/backup-and-recover.sh"
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
      ExecStart = "${pkgs.bash}/bin/bash ${backupScripts}/backup-and-recover.sh";
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
