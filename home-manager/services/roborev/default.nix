{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host) isGalactica isKyber isMatic;
  homeDir = config.home.homeDirectory;
  roborevBin = "${homeDir}/.local/bin/roborev";
  dataDir = "${homeDir}/.roborev";
  serverAddr = "127.0.0.1:7373";
  enabled = isGalactica || isKyber || isMatic;
in
lib.mkIf enabled {
  home.activation.roborevSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${dataDir}"
  '';

  launchd.agents.roborev = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./start.sh}"
        roborevBin
        serverAddr
      ];
      KeepAlive = true;
      RunAtLoad = true;
      EnvironmentVariables = {
        HOME = homeDir;
        ROBOREV_DATA_DIR = dataDir;
        PATH = "${homeDir}/.local/bin:${homeDir}/.bun/bin:/etc/profiles/per-user/${config.home.username}/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
      };
      StandardOutPath = "/tmp/roborev.log";
      StandardErrorPath = "/tmp/roborev.error.log";
    };
  };

  systemd.user.services.roborev = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "roborev code review daemon";
      Documentation = [ "https://github.com/roborev-dev/roborev" ];
      After = [ "network.target" ];
    }
    // lib.optionalAttrs isKyber {
      StartLimitIntervalSec = 300;
      StartLimitBurst = 3;
    };
    Service = {
      Type = "notify";
      ExecStart = "${pkgs.bash}/bin/bash ${./start.sh} ${roborevBin} ${serverAddr}";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "HOME=${homeDir}"
        "ROBOREV_DATA_DIR=${dataDir}"
        "PATH=${homeDir}/.local/bin:${homeDir}/.bun/bin:/etc/profiles/per-user/${config.home.username}/bin:${homeDir}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin"
      ];
    }
    // lib.optionalAttrs isKyber {
      ExecStartPre = [
        # Reclaim daemon port from orphaned processes
        "-${pkgs.procps}/bin/pkill -KILL -f '[r]oborev daemon run'"
        # Rotate opencode DB when it exceeds 500MB (accumulated session data from reviews)
        "-${pkgs.bash}/bin/bash -c 'db=${homeDir}/.local/share/opencode/opencode-stable.db; [ -f \"$db\" ] && sz=$(stat -c%%s \"$db\" 2>/dev/null || echo 0) && [ \"$sz\" -gt 524288000 ] && mv \"$db\" \"$db.rotated-$(date +%%Y%%m%%dT%%H%%M%%S)\" && rm -f \"$db\"-wal \"$db\"-shm'"
      ];
      RestartSec = 30;
      KillMode = "control-group";
      TimeoutStopSec = 30;
      TasksMax = 2048;
      CPUQuota = "400%";
      MemoryMax = "8G";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
