{
  config,
  lib,
  pkgs,
  ...
}:
let
  binPath = lib.makeBinPath [
    pkgs.bun
    pkgs.bash
    pkgs.coreutils
    pkgs.curl
    pkgs.jq
  ];
  # Every 3 hours, aligned to the wall clock.
  calendarHours = [
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
  launchd.agents.tokscale = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
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
      RunAtLoad = true;
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
      OnBootSec = "1min";
      OnCalendar = "*-*-* 0/3:00:00";
      Persistent = true;
      Unit = "tokscale.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
