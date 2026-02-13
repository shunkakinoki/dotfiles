{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir =
    config.home.homeDirectory
      or (if pkgs.stdenv.isDarwin then builtins.getEnv "HOME" else "/home/${config.home.username}");

  hydrateScript = pkgs.replaceVars ./scripts/hydrate.sh {
    aws = "${pkgs.awscli2}/bin/aws";
  };

  backupScript = pkgs.replaceVars ./scripts/backup.sh {
    aws = "${pkgs.awscli2}/bin/aws";
  };

  startScript = pkgs.replaceVars ./scripts/start.sh {
    sed = "${pkgs.gnused}/bin/sed";
    aws = "${pkgs.awscli2}/bin/aws";
  };

  # Smart wrapper that handles both NixOS and non-NixOS Linux
  # On NixOS: docker group is properly inherited, or use /run/wrappers/bin/sg
  # On non-NixOS: systemd user session may lack docker group, use /usr/bin/sg
  dockerStartScript = pkgs.writeShellScript "cliproxyapi-docker-start" ''
    SCRIPT="${pkgs.bash}/bin/bash ${startScript}"

    # Try docker directly first (works on NixOS or when user has docker group)
    if ${pkgs.docker}/bin/docker info >/dev/null 2>&1; then
      exec $SCRIPT
    fi

    # Docker not accessible directly, try sg to switch group
    if [ -x /run/wrappers/bin/sg ]; then
      exec /run/wrappers/bin/sg docker -c "$SCRIPT"
    elif [ -x /usr/bin/sg ]; then
      exec /usr/bin/sg docker -c "$SCRIPT"
    else
      echo "ERROR: Cannot access Docker. User not in docker group and no sg binary found." >&2
      exit 1
    fi
  '';

  wrapperScript = pkgs.replaceVars ./scripts/wrapper.sh {
    aws = "${pkgs.awscli2}/bin/aws";
  };

  cliWrapper = pkgs.writeShellScriptBin "cliproxyapi" (builtins.readFile wrapperScript);
in
{
  # Hydrate auth cache after home-manager switch
  home.activation.hydrateCliproxyAuths = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash ${hydrateScript} || true
  '';

  home.packages = lib.mkIf pkgs.stdenv.isDarwin [ cliWrapper ];

  # Main service
  launchd.agents.cliproxyapi = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${startScript}"
      ];
      Environment = {
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

  # Backup service - watches auth dir for changes
  launchd.agents.cliproxyapi-backup = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${backupScript}"
      ];
      Environment = {
        PATH = "${
          lib.makeBinPath [
            pkgs.bash
            pkgs.coreutils
            pkgs.awscli2
          ]
        }:/opt/homebrew/bin:/usr/local/bin:/usr/bin";
      };
      WatchPaths = [
        "${homeDir}/.cli-proxy-api/objectstore/auths"
        "${homeDir}/.ccs/cliproxy/auth"
      ];
      RunAtLoad = true;
      StandardOutPath = "/tmp/cliproxyapi-backup.log";
      StandardErrorPath = "/tmp/cliproxyapi-backup.error.log";
    };
  };

  # Linux systemd
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
    Install.WantedBy = [ "default.target" ];
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
    Unit.Description = "CLIProxyAPI auth backup";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${backupScript}";
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
