{
  config,
  lib,
  pkgs,
  utcOffsetHours ? 0,
  ...
}:
let
  binPath = lib.makeBinPath [
    pkgs.bun
    pkgs.bash
    pkgs.coreutils
  ];
  # launchd has no per-job timezone field, so convert the shared UTC schedule
  # into the host's local calendar hours.
  calendarHours = map (hour: lib.mod (hour + utcOffsetHours) 24) [
    0
    3
    6
    9
    12
    15
    18
    21
  ];
in
{
  # macOS (launchd)
  launchd.agents.tokscale = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./submit.sh}"
      ];
      EnvironmentVariables = {
        PATH = binPath + ":/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StartCalendarInterval = map (hour: {
        Hour = hour;
        Minute = 0;
      }) calendarHours;
      StandardOutPath = "/tmp/tokscale.log";
      StandardErrorPath = "/tmp/tokscale.error.log";
    };
  };

  # Linux (systemd)
  systemd.user.services.tokscale = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Submit local usage data to Tokscale";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "PATH=${binPath}:/usr/bin:/bin:/usr/sbin:/sbin"
      ];
      ExecStart = "${pkgs.bash}/bin/bash ${./submit.sh}";
      StandardOutput = "append:/tmp/tokscale.log";
      StandardError = "append:/tmp/tokscale.error.log";
    };
  };

  systemd.user.timers.tokscale = lib.mkIf pkgs.stdenv.isLinux {
    Unit.Description = "Submit local usage data to Tokscale every three hours";
    Timer = {
      OnCalendar = "*-*-* 0/3:00:00 UTC";
      Persistent = true;
      Unit = "tokscale.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
