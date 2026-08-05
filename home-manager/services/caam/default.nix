{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  caamBin = "${homeDir}/.local/bin/caam";
  pathEnv = "${homeDir}/.local/bin:${homeDir}/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
  # Every 15 minutes keeps vaults aligned without hammering SSH.
  syncIntervalSeconds = 900;
in
{
  # On every home-manager activation: discover SSH peers into the sync pool
  # and enable auto-sync after backup/refresh.
  home.activation.caamSyncSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./setup.sh}"
  '';

  # Persistent token-refresh daemon (foreground under launchd/systemd supervision).
  launchd.agents.caam-daemon = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        caamBin
        "daemon"
        "start"
        "--fg"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      EnvironmentVariables = {
        HOME = homeDir;
        PATH = pathEnv;
      };
      StandardOutPath = "/tmp/caam-daemon.log";
      StandardErrorPath = "/tmp/caam-daemon.error.log";
    };
  };

  # Periodic peer sync (freshness-based push/pull).
  launchd.agents.caam-sync = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./sync.sh}"
      ];
      StartInterval = syncIntervalSeconds;
      RunAtLoad = true;
      EnvironmentVariables = {
        HOME = homeDir;
        PATH = pathEnv;
      };
      StandardOutPath = "/tmp/caam-sync.log";
      StandardErrorPath = "/tmp/caam-sync.error.log";
    };
  };

  systemd.user.services.caam-daemon = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "CAAM token refresh daemon";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${caamBin} daemon start --fg";
      Restart = "always";
      RestartSec = 10;
      Environment = [
        "HOME=${homeDir}"
        "PATH=${pathEnv}"
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.caam-sync = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "CAAM multi-machine vault sync";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${./sync.sh}";
      Environment = [
        "HOME=${homeDir}"
        "PATH=${pathEnv}"
      ];
    };
  };

  systemd.user.timers.caam-sync = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Periodic CAAM vault sync";
    };
    Timer = {
      OnBootSec = "2min";
      OnUnitActiveSec = "${toString syncIntervalSeconds}s";
      Persistent = true;
      Unit = "caam-sync.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
