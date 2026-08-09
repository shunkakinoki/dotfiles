{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  systemd.user.services.t3-connect = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Keep the T3 remote server ready to accept connections";
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
      ExecStart = "${pkgs.bash}/bin/bash ${./connect.sh}";
    };
  };

  systemd.user.timers.t3-connect = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Timer to keep the T3 remote server ready to accept connections";
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
