{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host)
    isGalactica
    isKamino
    isKyber
    isMatic
    ;
  isKamino7 = isKamino && inputs.host.nodeName == "kamino7";
  homeDir = config.home.homeDirectory;
  roborevBin = "${homeDir}/.local/bin/roborev";
  dataDir = "${homeDir}/.roborev";
  serverAddr = "127.0.0.1:7373";
  enabled = isGalactica || isKyber || isMatic || isKamino7;
in
lib.mkIf enabled {
  home.activation.roborevSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${dataDir}"
  '';

  launchd.agents.roborev = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
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
      # Avoid launchd hot-looping a failed daemon and deprioritize review work
      # relative to interactive shells and editor processes.
      ThrottleInterval = 30;
      ProcessType = "Background";
      LowPriorityIO = true;
      Nice = 10;
      EnvironmentVariables = {
        HOME = homeDir;
        ROBOREV_DATA_DIR = dataDir;
        PATH = "${homeDir}/.local/bin:${homeDir}/.bun/bin:/etc/profiles/per-user/${config.home.username}/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
      };
      StandardOutPath = "/tmp/roborev.log";
      StandardErrorPath = "/tmp/roborev.error.log";
    };
  };

  systemd.user.services.roborev = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "roborev code review daemon";
      Documentation = [ "https://github.com/roborev-dev/roborev" ];
      After = [ "network.target" ];
    }
    // lib.optionalAttrs isKamino7 {
      ConditionPathIsExecutable = roborevBin;
      StartLimitIntervalSec = 300;
      StartLimitBurst = 3;
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
    // lib.optionalAttrs isKamino7 {
      RestartSec = 30;
      KillMode = "control-group";
      TimeoutStopSec = 60;
      TasksMax = 4096;
      CPUQuota = "1000%";
      MemoryHigh = "36G";
      MemoryMax = "42G";
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
      CPUQuota = "1600%";
      # At most two review workers run at a time, including queued panel members.
      # Bound their child tools and daemon housekeeping together; small random
      # reads and writes need IOPS limits as well as bandwidth limits.
      IOAccounting = true;
      IOReadBandwidthMax = "/ 20M";
      IOWriteBandwidthMax = "/ 10M";
      IOReadIOPSMax = "/ 200";
      IOWriteIOPSMax = "/ 100";
      # The config template caps review workers at two on every host.
      # MemoryHigh throttles via reclaim before MemoryMax kills the cgroup.
      MemoryHigh = "24G";
      MemoryMax = "32G";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
