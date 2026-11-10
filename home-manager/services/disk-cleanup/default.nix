{
  config,
  lib,
  pkgs,
  ...
}:
let
  servicePath =
    lib.makeBinPath (
      [
        pkgs.coreutils
        pkgs.findutils
        pkgs.git
        pkgs.gnused
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.procps ]
    )
    + ":/usr/bin:/bin:/usr/sbin:/sbin";
in
{
  systemd.user.services.disk-cleanup = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Reclaim stale caches, scratch trees, and Docker build state";
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      Environment = [ "PATH=${servicePath}" ];
      Nice = 19;
      IOSchedulingClass = "idle";
      ExecStart = "${pkgs.bash}/bin/bash ${./cleanup.sh}";
    };
  };

  systemd.user.timers.disk-cleanup = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit.Description = "Timer for stale cache cleanup";
    Timer = {
      OnCalendar = "*:0/5";
      Persistent = true;
      RandomizedDelaySec = "30s";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  launchd.agents.disk-cleanup = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./cleanup.sh}"
      ];
      EnvironmentVariables.PATH = servicePath;
      RunAtLoad = true;
      StartInterval = 300;
      LowPriorityIO = true;
      Nice = 19;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/disk-cleanup.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/disk-cleanup.error.log";
    };
  };
}
