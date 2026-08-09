{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  systemd.user.services.t3-warm = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Pre-warm npx cache for the T3 remote server";
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${
          lib.makeBinPath [
            pkgs.bash
            pkgs.coreutils
            pkgs.gcc
            pkgs.gnumake
            pkgs.nodejs
            pkgs.python3
          ]
        }"
      ];
      Nice = 19;
      IOSchedulingPriority = 7;
      ExecStart = "${pkgs.bash}/bin/bash ${./warm.sh}";
    };
  };

  systemd.user.timers.t3-warm = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Timer to pre-warm npx cache for the T3 remote server";
    };
    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "30m";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
