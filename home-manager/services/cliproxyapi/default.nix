{ pkgs, ... }:
let
  inherit (pkgs) lib;
  # Use build-time HOME for paths that need it at plist generation
  homeDir = builtins.getEnv "HOME";

  # Create start script with paths substituted at build time
  startScript = pkgs.replaceVars ./scripts/start.sh {
    aws = "${pkgs.awscli2}/bin/aws";
    sed = "${pkgs.gnused}/bin/sed";
    rsync = "${pkgs.rsync}/bin/rsync";
  };

  # Wrapper script that runs start.sh with docker group permissions
  # Note: sg is from shadow package, available as system binary /usr/bin/sg
  dockerStartScript = pkgs.writeShellScript "cliproxyapi-docker-start" ''
    exec /usr/bin/sg docker -c "${pkgs.bash}/bin/bash ${startScript}"
  '';

  # Create backup scripts with paths substituted at build time
  backupAuthScript = pkgs.replaceVars ./scripts/backup-auth.sh {
    aws = "${pkgs.awscli2}/bin/aws";
    rsync = "${pkgs.rsync}/bin/rsync";
  };
  backupAndRecoverScript = pkgs.replaceVars ./scripts/backup-and-recover.sh {
    bash = "${pkgs.bash}/bin/bash";
    backupAuthScript = backupAuthScript;
  };
in
{
  # Ensure auth cache is hydrated immediately after home-manager switch,
  # so first CLI invocation after a rebuild doesn't hit missing auth files.
  home.activation.hydrateCliproxyAuths = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash ${backupAuthScript} || true
  '';

  # Main cliproxyapi service
  launchd.agents.cliproxyapi = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${startScript}"
      ];
      Environment = {
        HOME = homeDir;
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
      After = [
        "network.target"
        "docker.service"
      ];
      Wants = [ "docker.service" ];
    };
    Service = {
      Type = "simple";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.gnused
          pkgs.bash
          pkgs.coreutils
          pkgs.awscli2
          pkgs.docker
        ]
      }";
      ExecStart = "${dockerStartScript}";
      Restart = "always";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Backup service with file watching for real-time sync
  launchd.agents.cliproxyapi-backup = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${backupAndRecoverScript}"
      ];
      Environment = {
        HOME = homeDir;
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
      # NOTE: dotfiles is excluded to prevent circular sync loops
      WatchPaths = [
        "${homeDir}/.cli-proxy-api/objectstore/auths"
        "${homeDir}/.ccs/cliproxy/auth"
      ];
      RunAtLoad = true;
      StandardOutPath = "/tmp/cliproxyapi-backup.log";
      StandardErrorPath = "/tmp/cliproxyapi-backup.error.log";
    };
  };

  systemd.user.paths.cliproxyapi-backup = lib.mkIf pkgs.stdenv.isLinux {
    Unit.Description = "Watch auth directories for changes";
    Path = {
      PathChanged = [
        "%h/.cli-proxy-api/objectstore/auths"
        "%h/.ccs/cliproxy/auth"
      ];
      Unit = "cliproxyapi-backup.service";
    };
    Install.WantedBy = [ "paths.target" ];
  };

  systemd.user.services.cliproxyapi-backup = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "CLIProxyAPI auth backup";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${backupAndRecoverScript}";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.awscli2
          pkgs.coreutils
          pkgs.rsync
        ]
      }";
    };
  };
}
