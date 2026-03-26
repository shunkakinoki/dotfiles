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

  commonScript = pkgs.replaceVars ./scripts/common.sh {
    aws = "${pkgs.awscli2}/bin/aws";
  };

  hydrateScript = pkgs.replaceVars ./scripts/hydrate.sh {
    common = commonScript;
  };

  backupScript = pkgs.replaceVars ./scripts/backup.sh {
    common = commonScript;
  };

  startScript = pkgs.replaceVars ./scripts/start.sh {
    sed = "${pkgs.gnused}/bin/sed";
    aws = "${pkgs.awscli2}/bin/aws";
    common = commonScript;
  };

  # Smart wrapper that handles both NixOS and non-NixOS Linux
  # On NixOS: docker group is properly inherited, or use /run/wrappers/bin/sg
  # On non-NixOS: systemd user session may lack docker group, use /usr/bin/sg
  dockerStartScript = pkgs.writeShellScript "cliproxyapi-docker-start" (
    builtins.readFile (
      pkgs.replaceVars ./scripts/docker-start.sh {
        inherit (pkgs) bash;
        start_script = startScript;
        inherit (pkgs) docker;
      }
    )
  );

  keychainSyncScript = pkgs.replaceVars ./scripts/keychain-sync.sh {
    email = "shunkakinoki@gmail.com";
    keychain_account = "shunkakinoki";
    jq = "${pkgs.jq}/bin/jq";
  };

  wrapperScript = pkgs.replaceVars ./scripts/wrapper.sh {
    common = commonScript;
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

  # Keychain sync - extract Claude/Codex OAuth from local stores into auth dir
  launchd.agents.cliproxyapi-keychain-sync = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${keychainSyncScript}"
      ];
      Environment = {
        PATH = "${
          lib.makeBinPath [
            pkgs.bash
            pkgs.coreutils
            pkgs.jq
          ]
        }:/usr/bin";
      };
      StartInterval = 300;
      RunAtLoad = true;
      StandardOutPath = "/tmp/cliproxyapi-keychain-sync.log";
      StandardErrorPath = "/tmp/cliproxyapi-keychain-sync.error.log";
    };
  };

  # Periodic sync - pull auth files from S3 every 5 minutes
  launchd.agents.cliproxyapi-sync = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${hydrateScript}"
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
      StartInterval = 300;
      StandardOutPath = "/tmp/cliproxyapi-sync.log";
      StandardErrorPath = "/tmp/cliproxyapi-sync.error.log";
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
          pkgs.curl
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

  # Periodic sync - pull auth files from S3 every 5 minutes
  systemd.user.timers.cliproxyapi-sync = lib.mkIf pkgs.stdenv.isLinux {
    Unit.Description = "Periodically sync auth files from S3";
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "cliproxyapi-sync.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.cliproxyapi-sync = lib.mkIf pkgs.stdenv.isLinux {
    Unit.Description = "CLIProxyAPI auth sync from S3";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${hydrateScript}";
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
