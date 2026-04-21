{ pkgs, ... }:
let
  inherit (pkgs) lib;
  cass = "$HOME/.local/bin/cass";
in
{
  # Persistent watcher - incrementally indexes new sessions via filesystem notifications
  launchd.agents.cass-watcher = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "-c"
        "${cass} index --watch"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/cass-watcher.log";
      StandardErrorPath = "/tmp/cass-watcher.error.log";
    };
  };

  # Daily remote sync + analytics rebuild (runs at 4am)
  launchd.agents.cass-daily = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./daily.sh}"
      ];
      StartCalendarInterval = [
        {
          Hour = 4;
          Minute = 0;
        }
      ];
      StandardOutPath = "/tmp/cass-daily.log";
      StandardErrorPath = "/tmp/cass-daily.error.log";
    };
  };

  systemd.user.services.cass-watcher = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "cass incremental session indexer (watch mode)";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -c '${cass} index --watch'";
      Restart = "always";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.cass-daily = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "cass daily remote sync and analytics rebuild";
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${./daily.sh}";
    };
  };

  systemd.user.timers.cass-daily = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "cass daily sync timer";
    };
    Timer = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
