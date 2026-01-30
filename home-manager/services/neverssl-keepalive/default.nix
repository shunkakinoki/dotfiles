{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  # macOS (launchd)
  launchd.agents.neverssl-keepalive = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./keepalive.sh}"
      ];
      Environment = {
        PATH = lib.makeBinPath [ pkgs.curl ] + ":/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StartInterval = 3;
      StandardOutPath = "/tmp/neverssl-keepalive.log";
      StandardErrorPath = "/tmp/neverssl-keepalive.error.log";
    };
  };

  # Linux (systemd)
  systemd.user.services.neverssl-keepalive = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Keep captive portal alive via neverssl.com";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.curl
          pkgs.bash
        ]
      }";
      ExecStart = "${pkgs.bash}/bin/bash ${./keepalive.sh}";
    };
  };

  systemd.user.timers.neverssl-keepalive = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Timer for neverssl captive portal keepalive";
    };
    Timer = {
      OnBootSec = "3s";
      OnUnitActiveSec = "3s";
      AccuracySec = "1s";
      Unit = "neverssl-keepalive.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
