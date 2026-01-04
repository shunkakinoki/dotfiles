{ pkgs, ... }:
let
  inherit (pkgs) lib;
  homeDir = builtins.getEnv "HOME";

  hydrateScript = pkgs.replaceVars ./scripts/hydrate.sh {
    aws = "${pkgs.awscli2}/bin/aws";
  };

  backupScript = pkgs.replaceVars ./scripts/backup.sh {
    aws = "${pkgs.awscli2}/bin/aws";
  };

  startScript = pkgs.replaceVars ./scripts/start.sh {
    sed = "${pkgs.gnused}/bin/sed";
  };

  dockerStartScript = pkgs.writeShellScript "cliproxyapi-docker-start" ''
    exec /usr/bin/sg docker -c "${pkgs.bash}/bin/bash ${startScript}"
  '';

  cliWrapper = pkgs.writeShellScriptBin "cliproxyapi" (builtins.readFile ./scripts/wrapper.sh);
in
{
  # Hydrate auth cache after home-manager switch
  home.activation = lib.optionalAttrs (lib ? hm && lib.hm ? dag) {
    hydrateCliproxyAuths = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.bash}/bin/bash ${hydrateScript} || true
    '';
  };

  home.packages = lib.mkIf pkgs.stdenv.isDarwin [ cliWrapper ];

  # Main service
  launchd.agents.cliproxyapi = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [ "${pkgs.bash}/bin/bash" "${startScript}" ];
      Environment = {
        HOME = homeDir;
        PATH = "${lib.makeBinPath [ pkgs.gnused pkgs.coreutils pkgs.awscli2 ]}:/opt/homebrew/bin:/usr/local/bin:/usr/bin";
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
      ProgramArguments = [ "${pkgs.bash}/bin/bash" "${backupScript}" ];
      Environment = {
        HOME = homeDir;
        PATH = "${lib.makeBinPath [ pkgs.bash pkgs.coreutils pkgs.awscli2 ]}:/opt/homebrew/bin:/usr/local/bin:/usr/bin";
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
      After = [ "network.target" "docker.service" ];
      Wants = [ "docker.service" ];
    };
    Service = {
      Type = "simple";
      Environment = "PATH=${lib.makeBinPath [ pkgs.gnused pkgs.bash pkgs.coreutils pkgs.awscli2 pkgs.docker ]}";
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
      Environment = "PATH=${lib.makeBinPath [ pkgs.bash pkgs.awscli2 pkgs.coreutils ]}";
    };
  };
}
