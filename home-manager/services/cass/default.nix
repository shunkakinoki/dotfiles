{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  # Do not run `cass index --watch` persistently. On large archives it can
  # wedge during startup, and launchd/systemd restart it indefinitely, which
  # blocks the TUI's otherwise usable lexical search path.

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
