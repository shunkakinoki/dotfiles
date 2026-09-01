{ pkgs, ... }:
let
  inherit (pkgs) lib;
  path = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.git
  ];
in
{
  launchd.agents.mempalace-exporter = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./export.sh}"
      ];
      Environment = {
        PATH = "${path}:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
      };
      StartInterval = 21600;
      StandardOutPath = "/tmp/mempalace-exporter.log";
      StandardErrorPath = "/tmp/mempalace-exporter.error.log";
    };
  };

  systemd.user.services.mempalace-exporter = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "MemPalace palace export to wiki";
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      Environment = [ "PATH=${path}" ];
      Nice = 19;
      IOSchedulingPriority = 7;
      ExecStart = "${pkgs.bash}/bin/bash ${./export.sh}";
    };
  };

  systemd.user.timers.mempalace-exporter = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Timer for MemPalace palace exporter";
    };
    Timer = {
      OnCalendar = "*-*-* 00/6:00:00";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
