{
  inputs,
  lib,
  pkgs,
  ...
}:
lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && (inputs.host.isKyber || inputs.host.isKamino || inputs.host.isMatic || inputs.host.isBeskar)) {
  systemd.user.services.disk-cleanup = {
    Unit = {
      Description = "Reclaim stale caches, agent data, and Docker build state";
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.findutils
            pkgs.git
            pkgs.gnused
            pkgs.procps
          ]
        }:/usr/bin:/bin"
      ];
      Nice = 19;
      IOSchedulingClass = "idle";
      ExecStart = "${pkgs.bash}/bin/bash ${./cleanup.sh}";
    };
  };

  systemd.user.timers.disk-cleanup = {
    Unit.Description = "Timer for stale cache cleanup";
    Timer = {
      OnCalendar = "*:0/30";
      Persistent = true;
      RandomizedDelaySec = "2m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
