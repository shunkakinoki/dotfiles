{ pkgs, ... }:
let
  inherit (pkgs) lib;

  keepaliveScript = pkgs.writeShellApplication {
    name = "neverssl-keepalive";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      set -euo pipefail
      curl -fsS --max-time 10 http://neverssl.com > /dev/null 2>&1 || true
    '';
  };
in
{
  launchd.agents.neverssl-keepalive = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${keepaliveScript}/bin/neverssl-keepalive"
      ];
      StartInterval = 3;
      StandardOutPath = "/tmp/neverssl-keepalive.log";
      StandardErrorPath = "/tmp/neverssl-keepalive.error.log";
    };
  };

  systemd.user.services.neverssl-keepalive = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Keep captive portal alive via neverssl.com";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${keepaliveScript}/bin/neverssl-keepalive";
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
