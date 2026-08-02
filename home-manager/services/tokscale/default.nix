{ pkgs, ... }:
let
  inherit (pkgs) lib;
  binPath = lib.makeBinPath [
    pkgs.bun
    pkgs.bash
    pkgs.coreutils
  ];
  # Every 3 hours.
  intervalSeconds = 10800;
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
      Environment = {
        PATH = binPath + ":/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StartInterval = intervalSeconds;
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
      Environment = "PATH=${binPath}";
      ExecStart = "${pkgs.bash}/bin/bash ${./submit.sh}";
    };
  };

  systemd.user.timers.tokscale = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Timer for Tokscale usage submission";
    };
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "3h";
      Persistent = true;
      Unit = "tokscale.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
