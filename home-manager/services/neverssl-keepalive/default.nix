{ pkgs }:
let
  keepaliveScript = pkgs.writeShellApplication {
    name = "neverssl-keepalive";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      set -euo pipefail
      if ! curl -fsS --max-time 10 http://neverssl.com > /dev/null 2>&1; then
        exit 0
      fi
    '';
  };
in
{
  systemd.user.services.neverssl-keepalive = {
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

  systemd.user.timers.neverssl-keepalive = {
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
