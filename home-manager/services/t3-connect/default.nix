{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  systemd.user.services.t3-connect = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Keep the T3 remote server ready to accept connections";
    };
    Service = {
      Type = "oneshot";
      Environment = [
        # node-gyp's generated Makefile shells out to sed/grep/awk/which, so a
        # minimal PATH fails the compile with `sed: command not found` rather
        # than anything that names the real dependency.
        "PATH=${
          lib.makeBinPath [
            pkgs.bash
            pkgs.coreutils
            pkgs.findutils
            pkgs.gawk
            pkgs.gcc
            pkgs.gnugrep
            pkgs.gnumake
            pkgs.gnused
            pkgs.nodejs
            pkgs.python3
            pkgs.which
          ]
        }"
      ];
      Nice = 19;
      IOSchedulingPriority = 7;
      ExecStart = "${pkgs.bash}/bin/bash ${./connect.sh}";
    };
  };

  systemd.user.timers.t3-connect = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
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
